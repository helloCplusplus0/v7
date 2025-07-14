import { render } from 'solid-js/web'
import { grpcClient } from '../shared/api/grpc-client'

function App() {
  return (
    <div style={{ padding: '20px' }}>
      <h1>🚀 V7 gRPC-Web测试</h1>
      <p>测试修复后的protobuf序列化通信</p>
      
      <div style={{ 'margin-top': '20px' }}>
        <h2>🔧 统一gRPC客户端测试</h2>
        <p>
          <a href="/test-unified-grpc.html" target="_blank">
            📋 打开统一gRPC客户端测试页面
          </a>
        </p>
        <p>
          <a href="/test-crud-api.html" target="_blank">
            📋 打开原始CRUD API测试页面
          </a>
        </p>
      </div>
      
      <div style={{ 'margin-top': '20px' }}>
        <h2>📊 状态信息</h2>
        <p>gRPC客户端已加载: {grpcClient ? '✅' : '❌'}</p>
        <p>后端地址: http://192.168.31.84:50053</p>
        <p>前端地址: http://192.168.31.84:5173</p>
      </div>
      
      <div style={{ 'margin-top': '20px' }}>
        <h2>🎯 MVP CRUD Slice</h2>
        <p>项目管理功能已集成统一gRPC客户端</p>
      </div>
    </div>
  )
}

render(() => <App />, document.getElementById('root')!) 