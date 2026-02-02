import { useEffect, useCallback } from 'react';
import { keycloak } from '../lib/keycloak';
import { useStore } from '../stores';

const TOKEN_REFRESH_INTERVAL = 30000; // 30 seconds
const TOKEN_MIN_VALIDITY = 60; // seconds

export function useAuth() {
  const { auth, setAuth, clearAuth } = useStore();

  const initKeycloak = useCallback(async () => {
    try {
      const authenticated = await keycloak.init({
        onLoad: 'login-required',
        checkLoginIframe: false,
      });

      if (authenticated) {
        setAuth({
          authenticated: true,
          token: keycloak.token ?? null,
          userId: keycloak.subject ?? null,
        });
      } else {
        clearAuth();
      }
    } catch (error) {
      console.error('Keycloak init failed:', error);
      clearAuth();
    }
  }, [setAuth, clearAuth]);

  // Token 自动刷新
  useEffect(() => {
    if (!auth.authenticated) return;

    const interval = setInterval(async () => {
      try {
        const refreshed = await keycloak.updateToken(TOKEN_MIN_VALIDITY);
        if (refreshed && keycloak.token) {
          setAuth({
            authenticated: true,
            token: keycloak.token,
            userId: keycloak.subject ?? null,
          });
        }
      } catch {
        // Token 刷新失败，重新登录
        keycloak.login();
      }
    }, TOKEN_REFRESH_INTERVAL);

    return () => clearInterval(interval);
  }, [auth.authenticated, setAuth]);

  // 初始化
  useEffect(() => {
    initKeycloak();
  }, [initKeycloak]);

  const logout = useCallback(() => {
    keycloak.logout();
    clearAuth();
  }, [clearAuth]);

  return { auth, logout };
}
