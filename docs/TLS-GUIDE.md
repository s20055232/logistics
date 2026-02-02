# TLS/PKI 完整指南

本文檔詳細說明 TLS 證書的核心概念，幫助你理解 `makefiles/tls.mk` 中的每個操作。

---

## 目錄

1. [PKI 信任鏈概述](#1-pki-信任鏈概述)
2. [Root CA（根憑證授權中心）](#2-root-ca根憑證授權中心)
3. [Intermediate CA（中繼憑證授權中心）](#3-intermediate-ca中繼憑證授權中心)
4. [Private Key 與 Public Key](#4-private-key-與-public-key)
5. [CSR（Certificate Signing Request）](#5-csrcertificate-signing-request)
6. [SAN（Subject Alternative Name）](#6-sansubject-alternative-name)
7. [證書有效期與更新策略](#7-證書有效期與更新策略)
8. [常見問題 FAQ](#8-常見問題-faq)
9. [OpenSSL 常用指令速查表](#9-openssl-常用指令速查表)

---

## 1. PKI 信任鏈概述

### 什麼是 PKI？

**PKI（Public Key Infrastructure，公鑰基礎設施）** 是一套用於管理數位證書和公私鑰的系統框架。它建立了一個「信任鏈」，讓電腦之間能夠安全地驗證彼此的身份。

### 3 層架構

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                       Root CA                               │
│                   （根憑證授權中心）                          │
│                                                             │
│    • 自簽名證書（Self-signed）                               │
│    • 信任鏈的最頂端                                          │
│    • 有效期：10-20 年                                        │
│    • 私鑰必須離線保存、密碼保護                               │
│                                                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ 簽發
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                   Intermediate CA                           │
│                  （中繼憑證授權中心）                         │
│                                                             │
│    • 由 Root CA 簽發                                         │
│    • 日常用於簽發伺服器證書                                   │
│    • 有效期：3-5 年                                          │
│    • 即使洩漏，也不影響 Root CA                              │
│                                                             │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          │ 簽發
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                  Server Certificate                         │
│                    （伺服器證書）                             │
│                                                             │
│    • 由 Intermediate CA 簽發                                 │
│    • 用於 HTTPS、TLS 連線                                    │
│    • 有效期：1 年（或更短）                                   │
│    • 包含 SAN（Subject Alternative Name）                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 為什麼需要階層式架構？

| 原因 | 說明 |
|------|------|
| **安全隔離** | Root CA 私鑰可以離線保存，降低洩漏風險 |
| **靈活撤銷** | 撤銷 Intermediate CA 不影響 Root CA |
| **分散管理** | 不同部門可以有各自的 Intermediate CA |
| **風險控制** | 即使 Intermediate CA 被攻破，更換成本較低 |

---

## 2. Root CA（根憑證授權中心）

### 什麼是 Root CA？

Root CA 是 PKI 信任鏈的**起點**。它是一個**自簽名證書**——用自己的私鑰簽署自己的證書，不需要其他 CA 來認證。

### 自簽名的概念

```
一般證書：
  證書內容 + CA 的數位簽章 = 證書
  （需要 CA 來簽發）

自簽名證書：
  證書內容 + 自己的數位簽章 = 證書
  （自己簽自己）
```

### 為什麼 Root CA 是信任的起點？

信任的傳遞過程：

```
1. 用戶的作業系統/瀏覽器預裝了受信任的 Root CA 證書
2. 用戶訪問 https://www.example.com
3. 伺服器發送證書鏈：Server Cert → Intermediate CA → Root CA
4. 瀏覽器驗證：
   - Server Cert 是否由 Intermediate CA 簽發？ ✓
   - Intermediate CA 是否由 Root CA 簽發？ ✓
   - Root CA 是否在受信任列表中？ ✓
5. 驗證通過，建立安全連線
```

### Root CA 的保護策略

```bash
# tls.mk 中的實作

# 1. 使用 AES-256 加密私鑰
openssl genrsa -aes256 -out root-ca.key 4096
#              ^^^^^^^ 產生私鑰時會要求設定密碼

# 2. 設定嚴格的檔案權限
chmod 400 root-ca.key  # 只有擁有者可讀

# 3. 建議：將私鑰備份到離線儲存裝置
```

**最佳實務**：
- Root CA 私鑰應存放在**離線環境**（如 USB 硬碟、HSM）
- 只有在需要簽發新的 Intermediate CA 時才使用
- 定期備份到多個安全地點

---

## 3. Intermediate CA（中繼憑證授權中心）

### 為什麼需要 Intermediate CA？

直接用 Root CA 簽發伺服器證書有什麼問題？

| 問題 | 說明 |
|------|------|
| **風險集中** | Root CA 私鑰需要頻繁使用，增加洩漏風險 |
| **撤銷困難** | 如果 Root CA 洩漏，所有證書都要重新簽發 |
| **管理不便** | 無法分散權限給不同團隊 |

### Intermediate CA 與 Root CA 的關係

```
Root CA                          Intermediate CA
─────────                        ─────────────────
私鑰 (root-ca.key)    ───簽發──▶  證書 (intermediate-ca.crt)
證書 (root-ca.crt)               私鑰 (intermediate-ca.key)
                                          │
                                          │ 簽發
                                          ▼
                                 Server Certificate
```

### `pathlen:0` 的意義

在 Intermediate CA 的擴展配置中：

```
basicConstraints = critical, CA:TRUE, pathlen:0
```

- `CA:TRUE`：這是一個 CA 證書，可以簽發其他證書
- `pathlen:0`：這個 CA **不能**再簽發其他 CA 證書，只能簽發終端證書

這防止了有人用 Intermediate CA 再創建一個子 CA。

### 憑證鏈（Certificate Chain）

```
┌─────────────────────────────────────────────────────────┐
│  ca-chain.crt（給客戶端驗證用）                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Intermediate CA Certificate                     │   │
│  │  (intermediate-ca.crt)                          │   │
│  └─────────────────────────────────────────────────┘   │
│                         +                               │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Root CA Certificate                             │   │
│  │  (root-ca.crt)                                  │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

```bash
# 建立 ca-chain.crt
cat intermediate-ca.crt root-ca.crt > ca-chain.crt
```

---

## 4. Private Key 與 Public Key

### 非對稱加密基礎

```
┌────────────────────────────────────────────────────────────┐
│                   RSA 金鑰對                                │
├────────────────────────────────────────────────────────────┤
│                                                            │
│   Private Key（私鑰）              Public Key（公鑰）       │
│   ┌──────────────────┐            ┌──────────────────┐    │
│   │                  │            │                  │    │
│   │  數學上相關聯     │◀──────────▶│  數學上相關聯     │    │
│   │                  │            │                  │    │
│   └──────────────────┘            └──────────────────┘    │
│            │                              │                │
│            ▼                              ▼                │
│   • 必須保密                      • 可以公開               │
│   • 用於解密                      • 用於加密               │
│   • 用於簽名                      • 用於驗證簽名           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### RSA 金鑰對的生成原理（簡化版）

```
1. 選擇兩個大質數 p 和 q
2. 計算 n = p × q
3. 計算歐拉函數 φ(n) = (p-1)(q-1)
4. 選擇公鑰指數 e（通常是 65537）
5. 計算私鑰指數 d，使得 e × d ≡ 1 (mod φ(n))

公鑰 = (e, n)
私鑰 = (d, n)
```

關鍵點：知道 n 不能輕易推導出 p 和 q（大數分解難題），所以公鑰可以公開。

### 為什麼私鑰可以獨立生成？

**重要概念**：私鑰的生成是純數學運算，不需要任何外部參與。

```bash
# 這個命令只是在本地生成隨機數並進行數學計算
openssl genrsa -out server.key 2048

# 不需要網路連線
# 不需要 CA
# 不需要任何外部服務
```

這就是為什麼 `gen-server-cert` 不依賴 `init-ca`：

```makefile
# tls.mk 中的依賴關係
gen-server-cert: init-cert-dirs    # 只需要目錄存在
sign-server-cert: gen-server-cert  # 這步才需要 CA
```

### 私鑰的重要性

```
⚠️  私鑰洩漏的後果：

1. 攻擊者可以偽裝成你的伺服器（中間人攻擊）
2. 攻擊者可以解密過去的通訊（如果沒有使用 PFS）
3. 需要撤銷證書並重新簽發
```

**保護措施**：
- 檔案權限設為 `600` 或 `400`
- 不要放入版本控制（加入 `.gitignore`）
- 考慮使用 HSM（Hardware Security Module）

---

## 5. CSR（Certificate Signing Request）

### CSR 是什麼？

CSR 是向 CA 申請簽發證書的「申請書」，包含：

```
┌─────────────────────────────────────────────────────────────┐
│                        CSR 結構                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Subject（身份資訊）                                      │
│     ┌─────────────────────────────────────────────────┐    │
│     │  CN = www.example.com    (Common Name)          │    │
│     │  O  = Example Inc.       (Organization)         │    │
│     │  C  = TW                 (Country)              │    │
│     │  ...                                            │    │
│     └─────────────────────────────────────────────────┘    │
│                                                             │
│  2. Public Key（公鑰）                                       │
│     ┌─────────────────────────────────────────────────┐    │
│     │  從私鑰推導出來的公鑰                             │    │
│     │  （公鑰可以安全公開）                             │    │
│     └─────────────────────────────────────────────────┘    │
│                                                             │
│  3. Signature（簽章）                                        │
│     ┌─────────────────────────────────────────────────┐    │
│     │  用私鑰對上述內容簽名                             │    │
│     │  證明「我確實擁有這個私鑰」                       │    │
│     └─────────────────────────────────────────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 為什麼 CSR 可以在 CA 存在前生成？

```
時間軸：
───────────────────────────────────────────────────────────────▶

  T1: 生成私鑰          T2: 生成 CSR           T3: CA 簽發證書
      │                     │                      │
      ▼                     ▼                      ▼
  ┌─────────┐          ┌─────────┐           ┌─────────┐
  │本地數學  │          │本地打包  │           │CA 驗證  │
  │運算      │          │資訊      │           │並簽名   │
  └─────────┘          └─────────┘           └─────────┘
      │                     │                      │
      │                     │                      │
   不需要 CA             不需要 CA              這步才需要 CA
```

**實際應用場景**：

```bash
# 場景：向公共 CA（如 Let's Encrypt）申請證書

# 步驟 1：在自己的伺服器上生成私鑰和 CSR
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr

# 步驟 2：只把 CSR 提交給 CA
#        私鑰永遠不會離開你的伺服器！

# 步驟 3：CA 驗證你的身份後，返回簽發的證書
```

### CSR 與 CA 的工作流程圖

```
┌──────────────────┐                    ┌──────────────────┐
│                  │                    │                  │
│    申請者         │                    │       CA         │
│    (Server)      │                    │                  │
│                  │                    │                  │
└────────┬─────────┘                    └────────┬─────────┘
         │                                       │
         │  1. 生成私鑰                           │
         │     openssl genrsa                    │
         │                                       │
         │  2. 生成 CSR                           │
         │     openssl req -new                  │
         │                                       │
         │  3. 提交 CSR ─────────────────────────▶│
         │     （不含私鑰）                        │
         │                                       │  4. 驗證 CSR
         │                                       │     檢查身份
         │                                       │
         │◀───────────────────────────────────── │  5. 簽發證書
         │     返回簽發的證書                      │     openssl x509
         │                                       │
         │  6. 部署證書                           │
         │     配置 nginx/apache                 │
         │                                       │
         ▼                                       ▼
```

---

## 6. SAN（Subject Alternative Name）

### 為什麼現代瀏覽器要求 SAN？

**歷史背景**：

```
傳統方式：用 CN（Common Name）指定域名
  Subject: CN=www.example.com

問題：
  1. 一個證書只能有一個 CN
  2. CN 欄位原本不是為了放域名設計的
  3. 2017年起，Chrome 58+ 已不再信任只用 CN 的證書
```

**解決方案**：使用 SAN 擴展

### SAN vs CN 的差異

| 特性 | CN (Common Name) | SAN (Subject Alternative Name) |
|------|------------------|--------------------------------|
| 位置 | Subject 欄位中 | X.509 v3 擴展中 |
| 數量 | 只能有一個 | 可以有多個 |
| 現代支援 | 已過時 | 必須使用 |
| 萬用字元 | 支援 | 支援 |

### SAN 配置範例

```bash
# san.cnf 檔案內容
subjectAltName = DNS:www.example.com,DNS:*.example.com,DNS:example.com
extendedKeyUsage = serverAuth,clientAuth
```

這個證書可以用於：

```
✅ www.example.com      # 明確指定
✅ api.example.com      # *.example.com 匹配
✅ app.example.com      # *.example.com 匹配
✅ example.com          # 明確指定

❌ sub.api.example.com  # 萬用字元只匹配一層
❌ other.com            # 完全不同的域名
```

### 萬用字元證書（Wildcard Certificate）

```
*.example.com 可以匹配：
  ✅ www.example.com
  ✅ api.example.com
  ✅ anything.example.com

不能匹配：
  ❌ example.com          (沒有子域名)
  ❌ sub.api.example.com  (兩層子域名)
  ❌ www.sub.example.com  (兩層子域名)
```

### extendedKeyUsage 的作用

```bash
extendedKeyUsage = serverAuth,clientAuth
```

| 值 | 意義 |
|---|------|
| `serverAuth` | 證書可用於 TLS 伺服器身份驗證 |
| `clientAuth` | 證書可用於 TLS 客戶端身份驗證（mTLS） |
| `codeSigning` | 證書可用於程式碼簽名 |
| `emailProtection` | 證書可用於電子郵件加密/簽名 |

---

## 7. 證書有效期與更新策略

### 建議的有效期

| 證書類型 | 建議有效期 | 更新頻率 | 原因 |
|---------|-----------|---------|------|
| **Root CA** | 20 年 | 極少更新 | 更換 Root CA 需要重建整個 PKI |
| **Intermediate CA** | 5 年 | 每 5 年 | 平衡安全性和管理便利性 |
| **Server Cert** | 1 年 | 每年 | 業界標準，降低私鑰洩漏風險 |

### 為什麼伺服器證書越來越短？

```
2012年以前：最長 5 年
2015年：最長 3 年
2018年：最長 2 年
2020年起：最長 1 年（398 天）

趨勢：Let's Encrypt 證書只有 90 天
```

**原因**：
- 縮短私鑰洩漏的影響時間
- 強制定期更新，確保使用最新的加密標準
- 推動自動化證書管理

### 更新流程

```
┌────────────────────────────────────────────────────────────┐
│                    證書生命週期                             │
├────────────────────────────────────────────────────────────┤
│                                                            │
│  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐ │
│  │ 簽發    │───▶│ 使用中  │───▶│ 即將到期 │───▶│ 更新    │ │
│  └─────────┘    └─────────┘    └─────────┘    └─────────┘ │
│       │              │              │              │       │
│       │              │              │              │       │
│   Day 0          Day 1-330      Day 330-365    Day 365    │
│                                                            │
│  建議：在到期前 30 天開始更新流程                           │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 8. 常見問題 FAQ

### Q: 為什麼瀏覽器顯示「不安全」？

**可能原因**：

| 情況 | 解決方案 |
|------|---------|
| 使用自簽 CA | 將 Root CA 加入系統信任：`make trust-ca-macos` |
| 證書過期 | 重新簽發：`make gen-tls-fast` |
| 域名不匹配 | 確認 SAN 包含正確的域名 |
| 證書鏈不完整 | 使用 fullchain.crt 而非單獨的 .crt |

### Q: fullchain.crt 和 .crt 有什麼不同？

```
server.crt（單一證書）：
┌─────────────────────────┐
│  Server Certificate     │
└─────────────────────────┘

server-fullchain.crt（完整鏈）：
┌─────────────────────────┐
│  Server Certificate     │
├─────────────────────────┤
│  Intermediate CA Cert   │
├─────────────────────────┤
│  Root CA Cert           │
└─────────────────────────┘
```

**何時使用哪個？**

| 場景 | 使用 |
|------|------|
| Nginx/Apache 配置 | fullchain.crt |
| Kubernetes TLS Secret | fullchain.crt |
| 內部服務（已信任 CA） | .crt 即可 |

### Q: 如何讓內部系統信任自簽 CA？

**方法 1：系統層級信任**

```bash
# macOS
make trust-ca-macos

# Linux
make trust-ca-linux
```

**方法 2：應用程式層級**

```bash
# curl
curl --cacert certs/root-ca/root-ca.crt https://api.example.com

# Python requests
requests.get('https://api.example.com', verify='certs/root-ca/root-ca.crt')

# Node.js
const https = require('https');
const fs = require('fs');
const agent = new https.Agent({
  ca: fs.readFileSync('certs/root-ca/root-ca.crt')
});
```

**方法 3：Kubernetes 中**

```bash
# 創建 CA ConfigMap
make create-k8s-ca-configmap

# 然後在 Pod 中掛載
volumeMounts:
  - name: ca-cert
    mountPath: /etc/ssl/certs/ca.crt
    subPath: ca.crt
volumes:
  - name: ca-cert
    configMap:
      name: example-cert-ca
```

### Q: 證書過期了怎麼辦？

```bash
# 1. 檢查證書到期時間
openssl x509 -in certs/servers/www.example.com/www.example.com.crt \
  -noout -dates

# 2. 重新簽發證書（不需要 Root CA 密碼）
make gen-tls-fast DOMAIN=www.example.com

# 3. 更新 Kubernetes Secret
make update-k8s-secret DOMAIN=www.example.com

# 4. 重啟相關服務或等待 Secret 自動更新
```

---

## 9. OpenSSL 常用指令速查表

### 查看證書資訊

```bash
# 查看證書完整內容
openssl x509 -in cert.crt -text -noout

# 查看證書摘要（主體、簽發者、日期）
openssl x509 -in cert.crt -noout -subject -issuer -dates

# 查看 SAN
openssl x509 -in cert.crt -noout -ext subjectAltName

# 查看證書指紋
openssl x509 -in cert.crt -noout -fingerprint -sha256
```

### 驗證證書

```bash
# 驗證證書是否由指定 CA 簽發
openssl verify -CAfile ca-chain.crt server.crt

# 驗證證書鏈
openssl verify -CAfile root-ca.crt -untrusted intermediate-ca.crt server.crt
```

### 查看 CSR 內容

```bash
openssl req -in server.csr -noout -text
```

### 查看私鑰資訊

```bash
# 查看私鑰（不顯示實際內容）
openssl rsa -in server.key -noout -text

# 檢查私鑰和證書是否匹配
openssl x509 -in server.crt -noout -modulus | openssl md5
openssl rsa -in server.key -noout -modulus | openssl md5
# 兩個 MD5 應該相同
```

### 測試 TLS 連線

```bash
# 連線並顯示證書鏈
openssl s_client -connect host:443 -showcerts

# 使用指定的 CA 驗證
openssl s_client -connect host:443 -CAfile ca-chain.crt

# 檢查支援的協議和加密套件
openssl s_client -connect host:443 -tls1_2
openssl s_client -connect host:443 -tls1_3
```

### 轉換格式

```bash
# PEM → DER
openssl x509 -in cert.pem -outform DER -out cert.der

# DER → PEM
openssl x509 -in cert.der -inform DER -out cert.pem

# PEM → PKCS#12 (用於 Windows/Java)
openssl pkcs12 -export -out cert.p12 \
  -inkey server.key -in server.crt -certfile ca-chain.crt
```

---

## 附錄：tls.mk 指令對照表

| 指令 | 說明 | 需要 Root CA 密碼？ |
|------|------|---------------------|
| `make init-pki` | 完整初始化 PKI | 是（設定密碼） |
| `make init-root-ca` | 僅初始化 Root CA | 是（設定密碼） |
| `make init-intermediate-ca` | 僅初始化 Intermediate CA | 是（輸入密碼） |
| `make gen-tls` | 完整流程 | 是 |
| `make gen-tls-fast` | 快速生成證書 | 否 |
| `make gen-cert-for domain=xxx` | 為指定域名生成證書 | 否 |
| `make verify-cert` | 驗證證書 | 否 |
| `make verify-chain` | 驗證完整信任鏈 | 否 |
| `make deploy-tls` | 部署到 Kubernetes | 否 |

---

*最後更新：2026-01*
