import { useAuth } from './hooks/useAuth';
import { useWebSocket } from './hooks/useWebSocket';
import { useMockData } from './hooks/useMockData';
import { Map } from './components/Map';
import { StatusPanel } from './components/StatusPanel';

// 开发模式：跳过认证，使用 mock 数据
const DEV_MODE = import.meta.env.DEV && !import.meta.env.VITE_KEYCLOAK_URL;

function App() {
  const { auth } = useAuth();

  // 从 URL 参数获取 container ID，或使用默认值
  const containerId = new URLSearchParams(window.location.search).get('container') || 'MSCU1234567';

  // 开发模式使用 mock 数据，生产模式使用 WebSocket
  useMockData();
  useWebSocket(DEV_MODE ? '' : containerId);

  // 生产模式：等待认证
  if (!DEV_MODE && !auth.authenticated) {
    return (
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100vh',
          background: '#f3f4f6',
        }}
      >
        <div style={{ textAlign: 'center' }}>
          <div
            style={{
              width: 40,
              height: 40,
              border: '3px solid #e5e7eb',
              borderTopColor: '#3b82f6',
              borderRadius: '50%',
              animation: 'spin 1s linear infinite',
              margin: '0 auto 16px',
            }}
          />
          <p style={{ color: '#6b7280' }}>Authenticating...</p>
        </div>
      </div>
    );
  }

  return (
    <div style={{ position: 'relative', width: '100vw', height: '100vh' }}>
      <Map />
      <StatusPanel />
    </div>
  );
}

export default App;
