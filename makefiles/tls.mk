# makefiles/tls.mk - TLS 證書管理模組（Production-Ready 3-Tier PKI）

# ============================================
# 變數定義
# ============================================
CERT_DIR := certs
ROOT_CA_DIR := $(CERT_DIR)/root-ca
INTERMEDIATE_CA_DIR := $(CERT_DIR)/intermediate-ca
SERVER_DIR := $(CERT_DIR)/servers

# 組織資訊
CA_ORG := Example Inc.
CA_COUNTRY := TW

# 預設域名設定
DOMAIN := www.example.com
NAMESPACE := app
SECRET_NAME := example-cert

# ============================================
# 目錄初始化
# ============================================
.PHONY: init-cert-dirs
init-cert-dirs:
	@echo "📁 創建證書目錄結構..."
	@mkdir -p $(ROOT_CA_DIR) $(INTERMEDIATE_CA_DIR) $(SERVER_DIR)/$(DOMAIN)
	@echo "✅ 目錄創建完成"

# ============================================
# Root CA 管理（密碼保護）
# ============================================
.PHONY: init-root-ca
init-root-ca: init-cert-dirs
	@echo "🔐 生成 Root CA（密碼保護）..."
	@echo "⚠️  請設定 Root CA 私鑰密碼（請妥善保管！）"
	@openssl genrsa -aes256 -out $(ROOT_CA_DIR)/root-ca.key 4096
	@echo ""
	@echo "📝 生成 Root CA 自簽名證書..."
	@openssl req -x509 -new \
		-key $(ROOT_CA_DIR)/root-ca.key \
		-sha256 -days 7300 \
		-out $(ROOT_CA_DIR)/root-ca.crt \
		-subj '/O=$(CA_ORG)/CN=$(CA_ORG) Root CA/C=$(CA_COUNTRY)'
	@echo "01" > $(ROOT_CA_DIR)/serial.txt
	@chmod 400 $(ROOT_CA_DIR)/root-ca.key
	@chmod 644 $(ROOT_CA_DIR)/root-ca.crt
	@echo ""
	@echo "✅ Root CA 初始化完成"
	@echo "   證書: $(ROOT_CA_DIR)/root-ca.crt"
	@echo "   私鑰: $(ROOT_CA_DIR)/root-ca.key (🔒 密碼保護)"
	@echo "   有效期: 20 年"
	@echo ""
	@echo "⚠️  重要：請將 Root CA 私鑰備份到安全的離線位置！"

# ============================================
# Intermediate CA 管理
# ============================================
.PHONY: init-intermediate-ca
init-intermediate-ca: init-cert-dirs
	@echo "🔑 生成 Intermediate CA..."
	@if [ ! -f $(ROOT_CA_DIR)/root-ca.key ]; then \
		echo "❌ Root CA 不存在，請先執行 'make init-root-ca'"; \
		exit 1; \
	fi
	@echo ""
	@echo "📝 生成 Intermediate CA 私鑰（無密碼，方便自動化）..."
	@openssl genrsa -out $(INTERMEDIATE_CA_DIR)/intermediate-ca.key 4096
	@echo ""
	@echo "📝 生成 Intermediate CA CSR..."
	@openssl req -new \
		-key $(INTERMEDIATE_CA_DIR)/intermediate-ca.key \
		-out $(INTERMEDIATE_CA_DIR)/intermediate-ca.csr \
		-subj '/O=$(CA_ORG)/CN=$(CA_ORG) Intermediate CA/C=$(CA_COUNTRY)'
	@echo ""
	@echo "📝 創建 Intermediate CA 擴展配置..."
	@echo "[v3_intermediate_ca]" > $(INTERMEDIATE_CA_DIR)/intermediate.cnf
	@echo "basicConstraints = critical, CA:TRUE, pathlen:0" >> $(INTERMEDIATE_CA_DIR)/intermediate.cnf
	@echo "keyUsage = critical, digitalSignature, cRLSign, keyCertSign" >> $(INTERMEDIATE_CA_DIR)/intermediate.cnf
	@echo "subjectKeyIdentifier = hash" >> $(INTERMEDIATE_CA_DIR)/intermediate.cnf
	@echo "authorityKeyIdentifier = keyid:always, issuer" >> $(INTERMEDIATE_CA_DIR)/intermediate.cnf
	@echo ""
	@echo "✍️  使用 Root CA 簽發 Intermediate CA 證書..."
	@echo "⚠️  請輸入 Root CA 私鑰密碼："
	@openssl x509 -req -days 1825 \
		-CA $(ROOT_CA_DIR)/root-ca.crt \
		-CAkey $(ROOT_CA_DIR)/root-ca.key \
		-CAserial $(ROOT_CA_DIR)/serial.txt \
		-in $(INTERMEDIATE_CA_DIR)/intermediate-ca.csr \
		-out $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt \
		-extfile $(INTERMEDIATE_CA_DIR)/intermediate.cnf \
		-extensions v3_intermediate_ca
	@echo "01" > $(INTERMEDIATE_CA_DIR)/serial.txt
	@echo ""
	@echo "📝 建立 CA 信任鏈..."
	@cat $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt $(ROOT_CA_DIR)/root-ca.crt \
		> $(INTERMEDIATE_CA_DIR)/ca-chain.crt
	@chmod 600 $(INTERMEDIATE_CA_DIR)/intermediate-ca.key
	@chmod 644 $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt
	@chmod 644 $(INTERMEDIATE_CA_DIR)/ca-chain.crt
	@echo ""
	@echo "✅ Intermediate CA 初始化完成"
	@echo "   證書: $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt"
	@echo "   私鑰: $(INTERMEDIATE_CA_DIR)/intermediate-ca.key"
	@echo "   CA 鏈: $(INTERMEDIATE_CA_DIR)/ca-chain.crt"
	@echo "   有效期: 5 年"

# ============================================
# PKI 完整初始化
# ============================================
.PHONY: init-pki
init-pki: init-root-ca init-intermediate-ca
	@echo ""
	@echo "🎉 ════════════════════════════════════════════"
	@echo "   PKI 基礎設施初始化完成！"
	@echo "   ════════════════════════════════════════════"
	@echo ""
	@echo "   架構: Root CA → Intermediate CA → Server Certs"
	@echo ""
	@echo "   📁 目錄結構:"
	@echo "   $(CERT_DIR)/"
	@echo "   ├── root-ca/           (🔒 離線保存)"
	@echo "   ├── intermediate-ca/   (日常簽發使用)"
	@echo "   └── servers/           (伺服器證書)"
	@echo ""

# ============================================
# 伺服器證書生成
# ============================================
.PHONY: gen-server-cert
gen-server-cert: init-cert-dirs
	@echo "🔑 生成伺服器私鑰和 CSR..."
	@mkdir -p $(SERVER_DIR)/$(DOMAIN)
	@openssl genrsa -out $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).key 2048
	@openssl req -new \
		-key $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).key \
		-out $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).csr \
		-subj "/CN=$(DOMAIN)/O=$(CA_ORG)"
	@echo "📝 創建 SAN 配置..."
	@echo "subjectAltName = DNS:$(DOMAIN),DNS:*.example.com,DNS:example.com" > $(SERVER_DIR)/$(DOMAIN)/san.cnf
	@echo "extendedKeyUsage = serverAuth,clientAuth" >> $(SERVER_DIR)/$(DOMAIN)/san.cnf
	@echo "basicConstraints = CA:FALSE" >> $(SERVER_DIR)/$(DOMAIN)/san.cnf
	@echo "keyUsage = digitalSignature, keyEncipherment" >> $(SERVER_DIR)/$(DOMAIN)/san.cnf
	@echo "✅ CSR 生成完成"

.PHONY: sign-server-cert
sign-server-cert: gen-server-cert
	@echo "✍️  使用 Intermediate CA 簽發證書..."
	@if [ ! -f $(INTERMEDIATE_CA_DIR)/intermediate-ca.key ]; then \
		echo "❌ Intermediate CA 不存在，請先執行 'make init-pki'"; \
		exit 1; \
	fi
	@if [ ! -f $(INTERMEDIATE_CA_DIR)/serial.txt ]; then \
		echo "01" > $(INTERMEDIATE_CA_DIR)/serial.txt; \
	fi
	@openssl x509 -req -days 365 \
		-CA $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt \
		-CAkey $(INTERMEDIATE_CA_DIR)/intermediate-ca.key \
		-CAserial $(INTERMEDIATE_CA_DIR)/serial.txt \
		-in $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).csr \
		-out $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt \
		-extfile $(SERVER_DIR)/$(DOMAIN)/san.cnf
	@echo "📝 建立完整證書鏈..."
	@cat $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt \
		$(INTERMEDIATE_CA_DIR)/intermediate-ca.crt \
		$(ROOT_CA_DIR)/root-ca.crt \
		> $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN)-fullchain.crt
	@chmod 600 $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).key
	@chmod 644 $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt
	@chmod 644 $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN)-fullchain.crt
	@echo "✅ 證書簽發完成"
	@echo "   證書: $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt"
	@echo "   完整鏈: $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN)-fullchain.crt"
	@echo "   有效期: 1 年"

# ============================================
# 便利指令
# ============================================
.PHONY: gen-tls
gen-tls: init-pki sign-server-cert verify-cert
	@echo "🎉 TLS 證書生成完成！"

.PHONY: gen-tls-fast
gen-tls-fast: sign-server-cert verify-cert
	@echo "🎉 TLS 證書生成完成！"

# ============================================
# 驗證和查看
# ============================================
.PHONY: verify-cert
verify-cert:
	@echo "🔍 驗證證書鏈..."
	@if [ -f $(INTERMEDIATE_CA_DIR)/ca-chain.crt ]; then \
		openssl verify -CAfile $(INTERMEDIATE_CA_DIR)/ca-chain.crt \
			$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt && \
		echo "" && \
		echo "📋 證書資訊:" && \
		openssl x509 -in $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt \
			-noout -subject -issuer -dates -ext subjectAltName; \
	else \
		echo "❌ CA 鏈不存在，請先執行 'make init-pki'"; \
		exit 1; \
	fi

.PHONY: verify-chain
verify-chain:
	@echo "🔍 驗證完整信任鏈..."
	@echo ""
	@echo "1️⃣  Root CA:"
	@openssl x509 -in $(ROOT_CA_DIR)/root-ca.crt -noout -subject -issuer
	@echo ""
	@echo "2️⃣  Intermediate CA:"
	@openssl x509 -in $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt -noout -subject -issuer
	@openssl verify -CAfile $(ROOT_CA_DIR)/root-ca.crt \
		$(INTERMEDIATE_CA_DIR)/intermediate-ca.crt
	@echo ""
	@echo "3️⃣  Server Certificate:"
	@openssl x509 -in $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt -noout -subject -issuer
	@openssl verify -CAfile $(INTERMEDIATE_CA_DIR)/ca-chain.crt \
		$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt

.PHONY: show-cert
show-cert:
	@echo "📄 伺服器證書詳細資訊:"
	@openssl x509 -in $(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).crt -text -noout

.PHONY: show-root-ca
show-root-ca:
	@echo "📄 Root CA 證書詳細資訊:"
	@openssl x509 -in $(ROOT_CA_DIR)/root-ca.crt -text -noout

.PHONY: show-intermediate-ca
show-intermediate-ca:
	@echo "📄 Intermediate CA 證書詳細資訊:"
	@openssl x509 -in $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt -text -noout

.PHONY: list-certs
list-certs:
	@echo "📋 PKI 證書清單"
	@echo "═══════════════════════════════════════════════"
	@echo ""
	@echo "🔒 Root CA:"
	@if [ -f $(ROOT_CA_DIR)/root-ca.crt ]; then \
		openssl x509 -in $(ROOT_CA_DIR)/root-ca.crt -noout -subject -dates | sed 's/^/   /'; \
	else \
		echo "   (未找到)"; \
	fi
	@echo ""
	@echo "🔑 Intermediate CA:"
	@if [ -f $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt ]; then \
		openssl x509 -in $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt -noout -subject -dates | sed 's/^/   /'; \
	else \
		echo "   (未找到)"; \
	fi
	@echo ""
	@echo "🌐 伺服器證書:"
	@if [ -d $(SERVER_DIR) ]; then \
		for dir in $(SERVER_DIR)/*; do \
			if [ -d "$$dir" ]; then \
				domain=$$(basename $$dir); \
				echo "   $$domain:"; \
				if [ -f "$$dir/$$domain.crt" ]; then \
					openssl x509 -in "$$dir/$$domain.crt" -noout -subject -dates | sed 's/^/      /'; \
				fi; \
			fi; \
		done; \
	else \
		echo "   (無伺服器證書)"; \
	fi

# ============================================
# Kubernetes 整合
# ============================================
.PHONY: create-k8s-secret
create-k8s-secret:
	@echo "☸️  創建 Kubernetes TLS Secret..."
	@kubectl create secret tls $(SECRET_NAME) \
		-n $(NAMESPACE) \
		--key=$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).key \
		--cert=$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN)-fullchain.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ Secret 創建完成: $(SECRET_NAME) (namespace: $(NAMESPACE))"

.PHONY: create-k8s-ca-configmap
create-k8s-ca-configmap:
	@echo "☸️  創建 CA ConfigMap（供客戶端信任）..."
	@kubectl create configmap $(SECRET_NAME)-ca \
		-n $(NAMESPACE) \
		--from-file=ca.crt=$(INTERMEDIATE_CA_DIR)/ca-chain.crt \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ ConfigMap 創建完成: $(SECRET_NAME)-ca"

.PHONY: update-k8s-secret
update-k8s-secret:
	@echo "🔄 更新 Kubernetes Secret..."
	@kubectl delete secret $(SECRET_NAME) -n $(NAMESPACE) --ignore-not-found
	@kubectl create secret tls $(SECRET_NAME) \
		-n $(NAMESPACE) \
		--key=$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN).key \
		--cert=$(SERVER_DIR)/$(DOMAIN)/$(DOMAIN)-fullchain.crt
	@echo "✅ Secret 更新完成"

.PHONY: deploy-tls
deploy-tls: gen-tls-fast create-k8s-secret create-k8s-ca-configmap
	@echo "🚀 TLS 證書已部署到 Kubernetes"

# ============================================
# 系統信任
# ============================================
.PHONY: trust-ca-macos
trust-ca-macos:
	@echo "🔐 將 Root CA 證書加入系統信任（macOS）..."
	@sudo security add-trusted-cert -d -r trustRoot \
		-k /Library/Keychains/System.keychain \
		$(ROOT_CA_DIR)/root-ca.crt
	@echo "✅ Root CA 證書已加入系統信任"

.PHONY: trust-ca-linux
trust-ca-linux:
	@echo "🔐 將 Root CA 證書加入系統信任（Linux）..."
	@sudo cp $(ROOT_CA_DIR)/root-ca.crt /usr/local/share/ca-certificates/example-root-ca.crt
	@sudo update-ca-certificates
	@echo "✅ Root CA 證書已加入系統信任"

# ============================================
# 進階功能：為任意域名生成證書
# ============================================
.PHONY: gen-cert-for
gen-cert-for:
	@if [ -z "$(domain)" ]; then \
		echo "❌ 請指定域名: make gen-cert-for domain=api.example.com"; \
		exit 1; \
	fi
	@if [ ! -f $(INTERMEDIATE_CA_DIR)/intermediate-ca.key ]; then \
		echo "❌ Intermediate CA 不存在，請先執行 'make init-pki'"; \
		exit 1; \
	fi
	@echo "🔑 生成 $(domain) 的證書..."
	@mkdir -p $(SERVER_DIR)/$(domain)
	@openssl genrsa -out $(SERVER_DIR)/$(domain)/$(domain).key 2048
	@openssl req -new \
		-key $(SERVER_DIR)/$(domain)/$(domain).key \
		-out $(SERVER_DIR)/$(domain)/$(domain).csr \
		-subj "/CN=$(domain)/O=$(CA_ORG)"
	@echo "subjectAltName = DNS:$(domain)" > $(SERVER_DIR)/$(domain)/san.cnf
	@echo "extendedKeyUsage = serverAuth,clientAuth" >> $(SERVER_DIR)/$(domain)/san.cnf
	@echo "basicConstraints = CA:FALSE" >> $(SERVER_DIR)/$(domain)/san.cnf
	@echo "keyUsage = digitalSignature, keyEncipherment" >> $(SERVER_DIR)/$(domain)/san.cnf
	@openssl x509 -req -days 365 \
		-CA $(INTERMEDIATE_CA_DIR)/intermediate-ca.crt \
		-CAkey $(INTERMEDIATE_CA_DIR)/intermediate-ca.key \
		-CAserial $(INTERMEDIATE_CA_DIR)/serial.txt \
		-in $(SERVER_DIR)/$(domain)/$(domain).csr \
		-out $(SERVER_DIR)/$(domain)/$(domain).crt \
		-extfile $(SERVER_DIR)/$(domain)/san.cnf
	@cat $(SERVER_DIR)/$(domain)/$(domain).crt \
		$(INTERMEDIATE_CA_DIR)/intermediate-ca.crt \
		$(ROOT_CA_DIR)/root-ca.crt \
		> $(SERVER_DIR)/$(domain)/$(domain)-fullchain.crt
	@chmod 600 $(SERVER_DIR)/$(domain)/$(domain).key
	@echo "✅ $(domain) 證書生成完成"
	@echo "   證書: $(SERVER_DIR)/$(domain)/$(domain).crt"
	@echo "   完整鏈: $(SERVER_DIR)/$(domain)/$(domain)-fullchain.crt"

# ============================================
# 清理
# ============================================
.PHONY: clean-server-certs
clean-server-certs:
	@echo "🧹 清理伺服器證書..."
	@rm -rf $(SERVER_DIR)
	@echo "✅ 伺服器證書已清理"

.PHONY: clean-intermediate-ca
clean-intermediate-ca:
	@echo "⚠️  警告: 這將刪除 Intermediate CA！"
	@read -p "確定要繼續嗎? [y/N] " confirm && [ "$$confirm" = "y" ]
	@rm -rf $(INTERMEDIATE_CA_DIR)
	@echo "✅ Intermediate CA 已清理"

.PHONY: clean-all-certs
clean-all-certs:
	@echo "⚠️  警告: 這將刪除所有證書，包括 Root CA！"
	@echo "⚠️  此操作不可逆，請確保已備份重要的私鑰！"
	@read -p "確定要繼續嗎? [y/N] " confirm && [ "$$confirm" = "y" ]
	@rm -rf $(CERT_DIR)
	@echo "✅ 所有證書已清理"

# ============================================
# 幫助文檔
# ============================================
.PHONY: help-tls
help-tls:
	@echo "═══════════════════════════════════════════════════════════"
	@echo "TLS 證書管理命令（3-Tier PKI）"
	@echo "═══════════════════════════════════════════════════════════"
	@echo ""
	@echo "📐 架構: Root CA → Intermediate CA → Server Certificates"
	@echo ""
	@echo "🔧 PKI 初始化（首次設置）:"
	@echo "  make init-pki             完整初始化 Root CA + Intermediate CA"
	@echo "  make init-root-ca         僅初始化 Root CA（密碼保護）"
	@echo "  make init-intermediate-ca 僅初始化 Intermediate CA"
	@echo ""
	@echo "🔑 生成伺服器證書:"
	@echo "  make gen-tls              完整流程（包含 PKI 初始化）"
	@echo "  make gen-tls-fast         快速生成（PKI 已存在時使用）"
	@echo "  make gen-cert-for domain=<域名>"
	@echo "                            為指定域名生成證書"
	@echo ""
	@echo "☸️  Kubernetes 部署:"
	@echo "  make create-k8s-secret    創建 TLS Secret"
	@echo "  make create-k8s-ca-configmap"
	@echo "                            創建 CA ConfigMap（供客戶端信任）"
	@echo "  make update-k8s-secret    更新 TLS Secret"
	@echo "  make deploy-tls           生成證書並部署到 K8s"
	@echo ""
	@echo "🔍 驗證和查看:"
	@echo "  make verify-cert          驗證伺服器證書"
	@echo "  make verify-chain         驗證完整信任鏈"
	@echo "  make show-cert            查看伺服器證書詳情"
	@echo "  make show-root-ca         查看 Root CA 證書詳情"
	@echo "  make show-intermediate-ca 查看 Intermediate CA 證書詳情"
	@echo "  make list-certs           列出所有證書"
	@echo ""
	@echo "🔐 系統信任:"
	@echo "  make trust-ca-macos       將 Root CA 加入系統信任（macOS）"
	@echo "  make trust-ca-linux       將 Root CA 加入系統信任（Linux）"
	@echo ""
	@echo "🧹 清理:"
	@echo "  make clean-server-certs   清理所有伺服器證書"
	@echo "  make clean-intermediate-ca 清理 Intermediate CA"
	@echo "  make clean-all-certs      清理所有證書（包含 Root CA）"
	@echo ""
	@echo "📝 變數設定:"
	@echo "  DOMAIN=<域名>             伺服器域名（預設: www.example.com）"
	@echo "  NAMESPACE=<命名空間>       K8s 命名空間（預設: app）"
	@echo "  SECRET_NAME=<名稱>         K8s Secret 名稱（預設: example-cert）"
	@echo "  CA_ORG=<組織名>            CA 組織名稱（預設: Example Inc.）"
	@echo ""
	@echo "📖 範例:"
	@echo "  # 首次設置（會要求設定 Root CA 密碼）"
	@echo "  make init-pki"
	@echo ""
	@echo "  # 日常生成證書（不需要 Root CA 密碼）"
	@echo "  make gen-tls-fast DOMAIN=api.example.com"
	@echo ""
	@echo "  # 部署到 Kubernetes"
	@echo "  make deploy-tls DOMAIN=app.example.com NAMESPACE=prod"
	@echo ""
	@echo "📚 詳細說明請參考: docs/TLS-GUIDE.md"
	@echo ""