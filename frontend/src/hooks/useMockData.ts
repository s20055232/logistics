import { useEffect, useRef } from 'react';
import { useStore } from '../stores';
import type { Route, TrackPoint, Position } from '../types';

// 鹿特丹港口坐标
const ROTTERDAM: Position = [4.5, 51.9];

// 四条航线的颜色
export const ROUTE_COLORS: Record<string, string> = {
  'NLRT-TW001': '#ef4444', // 红色 - 台湾
  'NLRT-AU001': '#22c55e', // 绿色 - 澳洲
  'NLRT-US001': '#3b82f6', // 蓝色 - 美国
  'NLRT-JP001': '#f59e0b', // 橙色 - 日本
};

// 模拟航线数据：从荷兰鹿特丹出发
const MOCK_ROUTES: Route[] = [
  // 1. 鹿特丹 -> 台湾高雄 (经苏伊士运河)
  {
    container_id: 'NLRT-TW001',
    path: [
      ROTTERDAM,
      [-5.0, 36.0],    // 直布罗陀海峡
      [10.0, 35.0],    // 地中海
      [32.3, 31.2],    // 苏伊士运河
      [43.0, 12.5],    // 红海-亚丁湾
      [73.0, 10.0],    // 印度洋
      [95.0, 5.0],     // 马六甲海峡
      [110.0, 10.0],   // 南海
      [120.3, 22.6],   // 台湾高雄
    ],
    stops: [
      { name: 'Rotterdam', coordinates: ROTTERDAM, sequence: 1 },
      { name: 'Gibraltar', coordinates: [-5.0, 36.0], sequence: 2 },
      { name: 'Suez Canal', coordinates: [32.3, 31.2], sequence: 3 },
      { name: 'Kaohsiung', coordinates: [120.3, 22.6], sequence: 4, isDestination: true },
    ],
    destination: { name: 'Kaohsiung, Taiwan', coordinates: [120.3, 22.6], sequence: 4, isDestination: true },
  },
  // 2. 鹿特丹 -> 澳洲悉尼 (经苏伊士运河)
  {
    container_id: 'NLRT-AU001',
    path: [
      ROTTERDAM,
      [-5.0, 36.0],    // 直布罗陀海峡
      [32.3, 31.2],    // 苏伊士运河
      [43.0, 12.5],    // 红海-亚丁湾
      [73.0, -5.0],    // 印度洋
      [105.0, -20.0],  // 澳洲西海岸
      [130.0, -25.0],  // 大澳大利亚湾
      [151.2, -33.9],  // 悉尼
    ],
    stops: [
      { name: 'Rotterdam', coordinates: ROTTERDAM, sequence: 1 },
      { name: 'Gibraltar', coordinates: [-5.0, 36.0], sequence: 2 },
      { name: 'Suez Canal', coordinates: [32.3, 31.2], sequence: 3 },
      { name: 'Sydney', coordinates: [151.2, -33.9], sequence: 4, isDestination: true },
    ],
    destination: { name: 'Sydney, Australia', coordinates: [151.2, -33.9], sequence: 4, isDestination: true },
  },
  // 3. 鹿特丹 -> 美国休斯顿 (跨大西洋)
  {
    container_id: 'NLRT-US001',
    path: [
      ROTTERDAM,
      [-10.0, 48.0],   // 英吉利海峡出口
      [-30.0, 40.0],   // 大西洋中部
      [-50.0, 32.0],   // 大西洋西部
      [-70.0, 28.0],   // 巴哈马附近
      [-82.0, 25.0],   // 佛罗里达海峡
      [-90.0, 27.0],   // 墨西哥湾
      [-95.0, 29.5],   // 休斯顿
    ],
    stops: [
      { name: 'Rotterdam', coordinates: ROTTERDAM, sequence: 1 },
      { name: 'Atlantic', coordinates: [-30.0, 40.0], sequence: 2 },
      { name: 'Gulf of Mexico', coordinates: [-90.0, 27.0], sequence: 3 },
      { name: 'Houston', coordinates: [-95.0, 29.5], sequence: 4, isDestination: true },
    ],
    destination: { name: 'Houston, USA', coordinates: [-95.0, 29.5], sequence: 4, isDestination: true },
  },
  // 4. 鹿特丹 -> 日本横滨 (经苏伊士运河)
  {
    container_id: 'NLRT-JP001',
    path: [
      ROTTERDAM,
      [-5.0, 36.0],    // 直布罗陀海峡
      [32.3, 31.2],    // 苏伊士运河
      [43.0, 12.5],    // 红海
      [80.0, 8.0],     // 印度洋
      [103.0, 1.3],    // 新加坡
      [120.0, 20.0],   // 南海
      [130.0, 30.0],   // 东海
      [139.6, 35.4],   // 横滨
    ],
    stops: [
      { name: 'Rotterdam', coordinates: ROTTERDAM, sequence: 1 },
      { name: 'Suez Canal', coordinates: [32.3, 31.2], sequence: 2 },
      { name: 'Singapore', coordinates: [103.0, 1.3], sequence: 3 },
      { name: 'Yokohama', coordinates: [139.6, 35.4], sequence: 4, isDestination: true },
    ],
    destination: { name: 'Yokohama, Japan', coordinates: [139.6, 35.4], sequence: 4, isDestination: true },
  },
];

// 沿航线插值计算当前位置
function interpolatePosition(path: Position[], progress: number): Position {
  const totalSegments = path.length - 1;
  const segmentIndex = Math.min(Math.floor(progress * totalSegments), totalSegments - 1);
  const segmentProgress = (progress * totalSegments) - segmentIndex;

  const start = path[segmentIndex];
  const end = path[segmentIndex + 1];

  return [
    start[0] + (end[0] - start[0]) * segmentProgress,
    start[1] + (end[1] - start[1]) * segmentProgress,
  ];
}

// 每条航线的进度状态
interface ShipProgress {
  containerId: string;
  progress: number;
  speed: number; // 不同船速度不同
}

export function useMockData() {
  const { mapReady, setRoutes, setPosition, setWsConnected } = useStore();
  const initializedRef = useRef(false);
  const progressRef = useRef<ShipProgress[]>([
    { containerId: 'NLRT-TW001', progress: 0.35, speed: 0.003 },
    { containerId: 'NLRT-AU001', progress: 0.50, speed: 0.002 },
    { containerId: 'NLRT-US001', progress: 0.25, speed: 0.004 },
    { containerId: 'NLRT-JP001', progress: 0.60, speed: 0.0025 },
  ]);

  useEffect(() => {
    if (!mapReady) return;

    // 初始化航线数据
    if (!initializedRef.current) {
      setRoutes(MOCK_ROUTES);
      setWsConnected(true);
      initializedRef.current = true;

      // 设置初始位置
      progressRef.current.forEach((ship) => {
        const route = MOCK_ROUTES.find((r) => r.container_id === ship.containerId);
        if (route) {
          const [lon, lat] = interpolatePosition(route.path, ship.progress);
          setPosition({
            container_id: ship.containerId,
            lat,
            lon,
            timestamp: new Date().toISOString(),
            speed: 10 + Math.random() * 5,
          });
        }
      });
    }

    // 模拟所有船舶移动
    const interval = setInterval(() => {
      progressRef.current.forEach((ship) => {
        ship.progress += ship.speed;
        if (ship.progress >= 1) {
          ship.progress = 0;
        }

        const route = MOCK_ROUTES.find((r) => r.container_id === ship.containerId);
        if (route) {
          const [lon, lat] = interpolatePosition(route.path, ship.progress);

          const mockPosition: TrackPoint = {
            container_id: ship.containerId,
            lat,
            lon,
            timestamp: new Date().toISOString(),
            speed: 10 + Math.random() * 5,
          };

          setPosition(mockPosition);
        }
      });
    }, 2000);

    return () => {
      clearInterval(interval);
    };
  }, [mapReady, setRoutes, setPosition, setWsConnected]);

  useEffect(() => {
    return () => {
      initializedRef.current = false;
      setWsConnected(false);
    };
  }, [setWsConnected]);
}
