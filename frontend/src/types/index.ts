// 与后端 Go TrackPoint 结构对应，字段名保持 snake_case
export interface TrackPoint {
  container_id: string;
  lat: number;
  lon: number;
  timestamp: string; // RFC3339
  speed: number;
}

// GeoJSON 标准格式，坐标是 [lon, lat]
export type Position = [number, number];

export interface StopPoint {
  name: string;
  coordinates: Position;
  sequence: number;
  isDestination?: boolean;
}

export interface Route {
  container_id: string;
  path: Position[];
  stops: StopPoint[];
  destination: StopPoint;
}

// WebSocket 消息类型
export type WSMessage =
  | { type: 'position'; data: TrackPoint }
  | { type: 'route'; data: Route }
  | { type: 'error'; message: string };

// 认证状态
export interface AuthState {
  authenticated: boolean;
  token: string | null;
  userId: string | null;
}

// GeoJSON 辅助类型
export interface GeoJSONPoint {
  type: 'Feature';
  properties: Record<string, unknown>;
  geometry: {
    type: 'Point';
    coordinates: Position;
  };
}

export interface GeoJSONLineString {
  type: 'Feature';
  properties: Record<string, unknown>;
  geometry: {
    type: 'LineString';
    coordinates: Position[];
  };
}

export interface GeoJSONFeatureCollection {
  type: 'FeatureCollection';
  features: GeoJSONPoint[];
}
