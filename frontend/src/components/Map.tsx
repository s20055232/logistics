import { useEffect, useRef } from 'react';
import maplibregl from 'maplibre-gl';
import 'maplibre-gl/dist/maplibre-gl.css';
import { useStore } from '../stores';
import { ROUTE_COLORS } from '../hooks/useMockData';
import type {
  Route,
  TrackPoint,
  Position,
  GeoJSONFeatureCollection,
  GeoJSONPoint,
} from '../types';

// 免费地图样式
const MAP_STYLE = 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';

// 默认颜色
const DEFAULT_COLOR = '#3b82f6';

function getRouteColor(containerId: string): string {
  return ROUTE_COLORS[containerId] || DEFAULT_COLOR;
}

// 将多条航线转换为 GeoJSON FeatureCollection
function routesToGeoJSON(routes: Route[]) {
  return {
    type: 'FeatureCollection' as const,
    features: routes.map((route) => ({
      type: 'Feature' as const,
      properties: {
        container_id: route.container_id,
        color: getRouteColor(route.container_id),
      },
      geometry: {
        type: 'LineString' as const,
        coordinates: route.path,
      },
    })),
  };
}

// 将所有停靠点转换为 GeoJSON
function stopsToGeoJSON(routes: Route[]): GeoJSONFeatureCollection {
  const features: GeoJSONPoint[] = [];
  routes.forEach((route) => {
    route.stops.forEach((stop) => {
      features.push({
        type: 'Feature',
        properties: {
          name: stop.name,
          sequence: String(stop.sequence),
          isDestination: stop.isDestination ?? false,
          container_id: route.container_id,
          color: getRouteColor(route.container_id),
        },
        geometry: {
          type: 'Point',
          coordinates: stop.coordinates,
        },
      });
    });
  });
  return { type: 'FeatureCollection', features };
}

// 将多艘船位置转换为 GeoJSON
function positionsToGeoJSON(positions: Record<string, TrackPoint>): GeoJSONFeatureCollection {
  const features: GeoJSONPoint[] = Object.values(positions).map((pos) => ({
    type: 'Feature',
    properties: {
      container_id: pos.container_id,
      speed: pos.speed,
      timestamp: pos.timestamp,
      color: getRouteColor(pos.container_id),
    },
    geometry: {
      type: 'Point',
      coordinates: [pos.lon, pos.lat],
    },
  }));
  return { type: 'FeatureCollection', features };
}

// 空数据
const EMPTY_COLLECTION: GeoJSONFeatureCollection = {
  type: 'FeatureCollection',
  features: [],
};

interface MapProps {
  initialCenter?: Position;
  initialZoom?: number;
}

export function Map({
  initialCenter = [50, 20], // 世界中心视角
  initialZoom = 2,
}: MapProps) {
  const mapContainer = useRef<HTMLDivElement>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<maplibregl.Marker[]>([]);
  const readyRef = useRef(false);

  const routes = useStore((s) => s.routes);
  const positions = useStore((s) => s.positions);
  const setMapReady = useStore((s) => s.setMapReady);

  // 初始化地图
  useEffect(() => {
    if (!mapContainer.current) return;

    const map = new maplibregl.Map({
      container: mapContainer.current,
      style: MAP_STYLE,
      center: initialCenter,
      zoom: initialZoom,
    });

    mapRef.current = map;

    map.on('load', () => {
      // 航线数据源
      map.addSource('routes', {
        type: 'geojson',
        data: EMPTY_COLLECTION,
      });

      // 停靠点数据源
      map.addSource('stops', {
        type: 'geojson',
        data: EMPTY_COLLECTION,
      });

      // 船舶位置数据源
      map.addSource('ships', {
        type: 'geojson',
        data: EMPTY_COLLECTION,
      });

      // 航线图层 - 使用数据驱动颜色
      map.addLayer({
        id: 'routes-layer',
        type: 'line',
        source: 'routes',
        layout: { 'line-join': 'round', 'line-cap': 'round' },
        paint: {
          'line-color': ['get', 'color'],
          'line-width': 3,
          'line-opacity': 0.7,
        },
      });

      // 停靠点图层
      map.addLayer({
        id: 'stops-layer',
        type: 'circle',
        source: 'stops',
        paint: {
          'circle-radius': 8,
          'circle-color': '#ffffff',
          'circle-stroke-color': ['get', 'color'],
          'circle-stroke-width': 2,
        },
      });

      // 停靠点序号
      map.addLayer({
        id: 'stops-labels',
        type: 'symbol',
        source: 'stops',
        layout: {
          'text-field': ['get', 'sequence'],
          'text-size': 10,
          'text-allow-overlap': true,
        },
        paint: {
          'text-color': ['get', 'color'],
        },
      });

      // 船舶发光效果
      map.addLayer({
        id: 'ships-glow',
        type: 'circle',
        source: 'ships',
        paint: {
          'circle-radius': 15,
          'circle-color': ['get', 'color'],
          'circle-opacity': 0.3,
          'circle-blur': 1,
        },
      });

      // 船舶标记
      map.addLayer({
        id: 'ships-marker',
        type: 'circle',
        source: 'ships',
        paint: {
          'circle-radius': 6,
          'circle-color': ['get', 'color'],
          'circle-stroke-color': '#ffffff',
          'circle-stroke-width': 2,
        },
      });

      readyRef.current = true;
      setMapReady(true);
    });

    return () => {
      readyRef.current = false;
      setMapReady(false);
      map.remove();
      mapRef.current = null;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 更新航线数据
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !readyRef.current) return;

    const routesSource = map.getSource('routes') as maplibregl.GeoJSONSource;
    const stopsSource = map.getSource('stops') as maplibregl.GeoJSONSource;

    if (routesSource) {
      routesSource.setData(routesToGeoJSON(routes));
    }
    if (stopsSource) {
      stopsSource.setData(stopsToGeoJSON(routes));
    }

    // 清除旧的目的港标记
    markersRef.current.forEach((m) => m.remove());
    markersRef.current = [];

    // 添加新的目的港标记
    routes.forEach((route) => {
      if (route.destination) {
        const color = getRouteColor(route.container_id);
        const el = document.createElement('div');
        el.innerHTML = `
          <div style="background:${color};color:white;padding:4px 8px;border-radius:4px;font-size:11px;font-weight:600;white-space:nowrap;box-shadow:0 2px 4px rgba(0,0,0,0.2);">
            ${route.destination.name}
          </div>
          <div style="width:0;height:0;border-left:6px solid transparent;border-right:6px solid transparent;border-top:6px solid ${color};margin:0 auto;"></div>
        `;
        const marker = new maplibregl.Marker({ element: el, anchor: 'bottom' })
          .setLngLat(route.destination.coordinates)
          .addTo(map);
        markersRef.current.push(marker);
      }
    });
  }, [routes]);

  // 更新船舶位置
  useEffect(() => {
    const map = mapRef.current;
    if (!map || !readyRef.current) return;

    const shipsSource = map.getSource('ships') as maplibregl.GeoJSONSource;
    if (shipsSource) {
      shipsSource.setData(positionsToGeoJSON(positions));
    }
  }, [positions]);

  return (
    <div
      ref={mapContainer}
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
      }}
    />
  );
}
