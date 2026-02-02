import { useEffect, useRef, useCallback } from 'react';
import { useStore } from '../stores';
import type { WSMessage } from '../types';

const WS_URL = import.meta.env.VITE_WS_URL || 'wss://logistics.example.com';
const RECONNECT_DELAY = 3000;

export function useWebSocket(containerId: string) {
  const wsRef = useRef<WebSocket | null>(null);
  const reconnectTimeoutRef = useRef<number | null>(null);
  const { auth, setPosition, setRoutes, setWsConnected } = useStore();

  // 如果没有 containerId，不做任何事（开发模式）
  const enabled = Boolean(containerId);

  const connect = useCallback(() => {
    if (!enabled || !auth.token) return;

    // 清理之前的连接
    if (wsRef.current) {
      wsRef.current.close();
    }

    const url = `${WS_URL}/api/track/${containerId}?token=${auth.token}`;
    const ws = new WebSocket(url);
    wsRef.current = ws;

    ws.onopen = () => {
      setWsConnected(true);
      console.log('WebSocket connected');
    };

    ws.onmessage = (event) => {
      try {
        const msg: WSMessage = JSON.parse(event.data);
        switch (msg.type) {
          case 'position':
            setPosition(msg.data);
            break;
          case 'route':
            // 单个航线更新，添加到列表
            setRoutes([msg.data]);
            break;
          case 'error':
            console.error('WebSocket error:', msg.message);
            break;
        }
      } catch (e) {
        console.error('Failed to parse WebSocket message:', e);
      }
    };

    ws.onclose = () => {
      setWsConnected(false);
      console.log('WebSocket disconnected, reconnecting...');
      // 自动重连
      reconnectTimeoutRef.current = window.setTimeout(connect, RECONNECT_DELAY);
    };

    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
  }, [enabled, auth.token, containerId, setPosition, setRoutes, setWsConnected]);

  useEffect(() => {
    // 开发模式不连接 WebSocket
    if (!enabled) return;

    if (auth.authenticated && auth.token) {
      connect();
    }

    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, [enabled, auth.authenticated, auth.token, connect]);

  const disconnect = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current);
    }
    if (wsRef.current) {
      wsRef.current.close();
      wsRef.current = null;
    }
  }, []);

  return { disconnect };
}
