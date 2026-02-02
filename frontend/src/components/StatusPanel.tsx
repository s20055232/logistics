import { useStore } from '../stores';
import { ROUTE_COLORS } from '../hooks/useMockData';

// 航线目的地名称
const ROUTE_DESTINATIONS: Record<string, string> = {
  'NLRT-TW001': 'Taiwan',
  'NLRT-AU001': 'Australia',
  'NLRT-US001': 'USA',
  'NLRT-JP001': 'Japan',
};

export function StatusPanel() {
  const { positions, wsConnected } = useStore();
  const shipList = Object.values(positions);

  return (
    <div
      style={{
        position: 'absolute',
        top: 16,
        left: 16,
        background: 'white',
        padding: 16,
        borderRadius: 8,
        boxShadow: '0 2px 8px rgba(0,0,0,0.15)',
        minWidth: 220,
        maxHeight: 'calc(100vh - 32px)',
        overflowY: 'auto',
        zIndex: 10,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 8,
          marginBottom: 12,
          paddingBottom: 12,
          borderBottom: '1px solid #e5e7eb',
        }}
      >
        <div
          style={{
            width: 8,
            height: 8,
            borderRadius: '50%',
            background: wsConnected ? '#22c55e' : '#ef4444',
          }}
        />
        <span style={{ fontSize: 12, color: '#6b7280' }}>
          {wsConnected ? `${shipList.length} vessels tracking` : 'Disconnected'}
        </span>
      </div>

      {shipList.length > 0 ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {shipList.map((ship) => {
            const color = ROUTE_COLORS[ship.container_id] || '#3b82f6';
            const destination = ROUTE_DESTINATIONS[ship.container_id] || 'Unknown';
            return (
              <div
                key={ship.container_id}
                style={{
                  padding: 10,
                  borderRadius: 6,
                  background: '#f9fafb',
                  borderLeft: `4px solid ${color}`,
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    marginBottom: 6,
                  }}
                >
                  <span style={{ fontSize: 12, fontWeight: 600, color: '#1f2937' }}>
                    {ship.container_id}
                  </span>
                  <span
                    style={{
                      fontSize: 10,
                      padding: '2px 6px',
                      borderRadius: 4,
                      background: color,
                      color: 'white',
                    }}
                  >
                    → {destination}
                  </span>
                </div>
                <div style={{ fontSize: 11, color: '#6b7280', lineHeight: 1.5 }}>
                  <div>
                    {ship.lat.toFixed(3)}°, {ship.lon.toFixed(3)}°
                  </div>
                  <div>{ship.speed.toFixed(1)} knots</div>
                </div>
              </div>
            );
          })}
        </div>
      ) : (
        <div style={{ color: '#9ca3af', fontSize: 13 }}>Waiting for data...</div>
      )}

      {/* 图例 */}
      <div
        style={{
          marginTop: 16,
          paddingTop: 12,
          borderTop: '1px solid #e5e7eb',
          fontSize: 11,
          color: '#9ca3af',
        }}
      >
        <div style={{ marginBottom: 6, fontWeight: 500 }}>Routes from Rotterdam</div>
        {Object.entries(ROUTE_COLORS).map(([id, color]) => (
          <div key={id} style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
            <div style={{ width: 12, height: 3, background: color, borderRadius: 2 }} />
            <span>{ROUTE_DESTINATIONS[id]}</span>
          </div>
        ))}
      </div>
    </div>
  );
}
