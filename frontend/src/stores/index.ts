import { create } from 'zustand';
import type { TrackPoint, Route, AuthState } from '../types';

interface AppState {
  // 认证
  auth: AuthState;
  setAuth: (auth: AuthState) => void;
  clearAuth: () => void;

  // 多条航线
  routes: Route[];
  setRoutes: (routes: Route[]) => void;

  // 多艘船的实时位置 (key: container_id)
  positions: Record<string, TrackPoint>;
  setPosition: (point: TrackPoint) => void;
  setPositions: (positions: Record<string, TrackPoint>) => void;

  // 连接状态
  wsConnected: boolean;
  setWsConnected: (connected: boolean) => void;

  // 地图就绪状态
  mapReady: boolean;
  setMapReady: (ready: boolean) => void;
}

export const useStore = create<AppState>((set) => ({
  // 认证
  auth: { authenticated: false, token: null, userId: null },
  setAuth: (auth) => set({ auth }),
  clearAuth: () => set({ auth: { authenticated: false, token: null, userId: null } }),

  // 多条航线
  routes: [],
  setRoutes: (routes) => set({ routes }),

  // 多艘船位置
  positions: {},
  setPosition: (point) =>
    set((state) => ({
      positions: { ...state.positions, [point.container_id]: point },
    })),
  setPositions: (positions) => set({ positions }),

  // 连接状态
  wsConnected: false,
  setWsConnected: (wsConnected) => set({ wsConnected }),

  // 地图就绪
  mapReady: false,
  setMapReady: (mapReady) => set({ mapReady }),
}));
