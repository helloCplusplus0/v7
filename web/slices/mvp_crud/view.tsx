// 🎨 MVP CRUD - UI组件实现
// 现代化、响应式的CRUD界面，遵循Web v7切片独立性原则

import { createSignal, For, Show, onMount } from 'solid-js';
import { useCrud } from './hooks';
import type { Item, CreateItemRequest } from './types';
import './styles.css'; // 引入切片独立样式

// 简化的CRUD视图组件
export function CrudView() {
  const crud = useCrud();
  const [showCreateForm, setShowCreateForm] = createSignal(false);
  const [newItemName, setNewItemName] = createSignal('');
  const [newItemValue, setNewItemValue] = createSignal(0);
  const [newItemDescription, setNewItemDescription] = createSignal('');
  const [editingItem, setEditingItem] = createSignal<Item | null>(null);

  // 页面加载时获取数据
  onMount(() => {
    crud.loadItems();
  });

  const handleCreateItem = async () => {
    const description = newItemDescription().trim();
    const data: CreateItemRequest = {
      name: newItemName(),
      value: newItemValue(),
      ...(description && { description }),
    };

    try {
      await crud.createItem(data);
      resetForm();
    } catch (error) {
      console.error('创建失败:', error);
    }
  };

  const handleUpdateItem = async () => {
    const item = editingItem();
    console.log('🔍 handleUpdateItem called, editingItem:', item);
    if (!item) {
      console.error('❌ No editing item found!');
      return;
    }

    try {
      const description = newItemDescription().trim();
      const updateData = {
        name: newItemName(),
        value: newItemValue(),
        ...(description && { description }),
      };
      console.log('📝 Updating item:', item.id, 'with data:', updateData);
      await crud.updateItem(item.id, updateData);
      console.log('✅ Update successful');
      resetForm();
    } catch (error) {
      console.error('❌ 更新失败:', error);
    }
  };

  const handleDeleteItem = async (id: string) => {
    if (confirm('确定要删除这个项目吗？')) {
      try {
        await crud.deleteItem(id);
      } catch (error) {
        console.error('删除失败:', error);
      }
    }
  };

  const handleEditItem = (item: Item) => {
    setEditingItem(item);
    setNewItemName(item.name);
    setNewItemValue(item.value);
    setNewItemDescription(item.description || '');
    setShowCreateForm(true);
  };

  const resetForm = () => {
    setEditingItem(null);
    setNewItemName('');
    setNewItemValue(0);
    setNewItemDescription('');
    setShowCreateForm(false);
  };

  const currentStats = () => {
    const items = crud.state.items;
    const total = items.length;
    const average = total > 0 ? Math.round(items.reduce((sum, item) => sum + item.value, 0) / total) : 0;
    const maxValue = total > 0 ? Math.max(...items.map(item => item.value)) : 0;
    return { total, average, maxValue };
  };

  return (
    <div class="crud-container">
      {/* 页面头部 */}
      <div class="crud-header">
        <div class="crud-title-section">
          <h1 class="crud-title">
            <span class="title-icon">🗂️</span>
            项目管理
          </h1>
          <p class="crud-subtitle">管理和组织您的项目，提升工作效率</p>
        </div>
        
        <div class="crud-stats">
          <div class="stat-item">
            <span class="stat-value">{currentStats().total}</span>
            <span class="stat-label">总项目</span>
          </div>
          <Show when={currentStats().total > 0}>
            <div class="stat-item">
              <span class="stat-value">{currentStats().average}</span>
              <span class="stat-label">平均值</span>
            </div>
            <div class="stat-item">
              <span class="stat-value">{currentStats().maxValue}</span>
              <span class="stat-label">最大值</span>
            </div>
          </Show>
        </div>
      </div>

      {/* 操作栏 */}
      <div class="crud-actions">
        <div class="crud-actions-left">
          <button
            onClick={() => crud.refresh()}
            disabled={crud.isLoading()}
            class="btn btn-secondary"
            title="刷新数据"
          >
            <span class="btn-icon">{crud.isLoading() ? '🔄' : '↻'}</span>
            刷新
          </button>
          
          <Show when={crud.state.total > 0}>
            <div class="crud-sort-controls">
              <select 
                class="sort-select"
                onChange={(e) => crud.sort(e.currentTarget.value as any)}
                title="排序方式"
              >
                <option value="created_at">按创建时间</option>
                <option value="name">按名称</option>
                <option value="value">按数值</option>
              </select>
            </div>
          </Show>
        </div>
        
        <button
          onClick={() => setShowCreateForm(true)}
          class="btn btn-primary"
          title="创建新项目"
        >
          <span class="btn-icon">✨</span>
          创建项目
        </button>
      </div>

      {/* 错误提示 */}
      <Show when={crud.error()}>
        <div class="crud-error">
          <div class="error-content">
            <span class="error-icon">⚠️</span>
            <span class="error-message">{crud.error()}</span>
            <button
              onClick={() => crud.clearError()}
              class="error-close"
              title="关闭错误提示"
            >
              ✕
            </button>
          </div>
        </div>
      </Show>

      {/* 创建/编辑表单 */}
      <Show when={showCreateForm()}>
        <div class="crud-form-overlay" onClick={(e) => e.target === e.currentTarget && resetForm()}>
          <div class="crud-form">
            <div class="form-header">
              <h3 class="form-title">
                <span class="form-icon">{editingItem() ? '✏️' : '📝'}</span>
                {editingItem() ? '编辑项目' : '创建新项目'}
              </h3>
              <button
                onClick={resetForm}
                class="form-close"
                title="关闭表单"
              >
                ✕
              </button>
            </div>
            
            <div class="form-body">
              <div class="form-group">
                <label class="form-label">
                  <span class="label-text">项目名称</span>
                  <span class="label-required">*</span>
                </label>
                <input
                  type="text"
                  value={newItemName()}
                  onInput={(e) => setNewItemName(e.currentTarget.value)}
                  class="form-input"
                  placeholder="请输入有意义的项目名称"
                  maxLength={100}
                  autofocus
                />
                <div class="input-hint">
                  <span class={newItemName().length > 80 ? 'hint-warning' : ''}>
                    {newItemName().length}/100 字符
                  </span>
                </div>
              </div>
              
              <div class="form-group">
                <label class="form-label">
                  <span class="label-text">项目描述</span>
                </label>
                <textarea
                  value={newItemDescription()}
                  onInput={(e) => setNewItemDescription(e.currentTarget.value)}
                  class="form-textarea"
                  placeholder="描述项目的目标、内容或备注信息"
                  rows={3}
                  maxLength={500}
                />
                <div class="input-hint">
                  <span class={newItemDescription().length > 400 ? 'hint-warning' : ''}>
                    {newItemDescription().length}/500 字符
                  </span>
                </div>
              </div>
              
              <div class="form-group">
                <label class="form-label">
                  <span class="label-text">项目数值</span>
                  <span class="label-required">*</span>
                </label>
                <input
                  type="number"
                  value={newItemValue()}
                  onInput={(e) => setNewItemValue(parseInt(e.currentTarget.value) || 0)}
                  class="form-input"
                  placeholder="请输入项目数值"
                  min={0}
                  max={1000000}
                  step={1}
                />
                <div class="input-hint">
                  数值范围：0-1,000,000
                </div>
              </div>
            </div>
            
            <div class="form-footer">
              <button
                onClick={resetForm}
                class="btn btn-secondary"
                disabled={crud.isLoading()}
              >
                取消
              </button>
              <button
                onClick={() => {
                  const isEditing = editingItem();
                  console.log('🖱️ Form submit button clicked, isEditing:', isEditing);
                  if (isEditing) {
                    console.log('🔄 Calling handleUpdateItem');
                    handleUpdateItem();
                  } else {
                    console.log('➕ Calling handleCreateItem');
                    handleCreateItem();
                  }
                }}
                disabled={!newItemName().trim() || crud.isLoading()}
                class="btn btn-primary"
              >
                {crud.isLoading() ? (
                  <>
                    <span class="btn-spinner">⏳</span>
                    {editingItem() ? '更新中...' : '创建中...'}
                  </>
                ) : (
                  <>
                    <span class="btn-icon">{editingItem() ? '💾' : '✅'}</span>
                    {editingItem() ? '确认更新' : '确认创建'}
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      </Show>

      {/* 加载状态 */}
      <Show when={crud.isLoading() && !showCreateForm()}>
        <div class="crud-loading">
          <div class="loading-spinner">
            <div class="spinner-ring"></div>
            <div class="spinner-ring"></div>
            <div class="spinner-ring"></div>
          </div>
          <p class="loading-text">正在加载项目数据...</p>
        </div>
      </Show>

      {/* 项目列表 */}
      <Show when={!crud.isLoading()}>
        <Show 
          when={crud.hasItems()}
          fallback={
            <div class="crud-empty">
              <div class="empty-icon">📦</div>
              <h3 class="empty-title">暂无项目</h3>
              <p class="empty-description">
                还没有创建任何项目，点击下方按钮开始创建您的第一个项目。
              </p>
              <button
                onClick={() => setShowCreateForm(true)}
                class="btn btn-primary btn-large"
              >
                <span class="btn-icon">🚀</span>
                创建第一个项目
              </button>
            </div>
          }
        >
          <div class="crud-content">
            {/* 项目网格 */}
            <div class="items-grid">
              <For each={crud.state.items}>
                {(item: Item) => (
                  <div class="item-card" tabindex="0">
                    <div class="item-header">
                      <h4 class="item-name" title={item.name}>
                        {item.name}
                      </h4>
                      <div class="item-value">
                        <span class="value-number">{item.value.toLocaleString()}</span>
                      </div>
                    </div>
                    
                    <Show when={item.description}>
                      <div class="item-description" title={item.description}>
                        {item.description}
                      </div>
                    </Show>
                    
                    <div class="item-meta">
                      <div class="item-time">
                        <span class="time-icon">🕒</span>
                        <span class="time-text">
                          {new Date(item.created_at).toLocaleDateString('zh-CN', {
                            year: 'numeric',
                            month: 'short',
                            day: 'numeric',
                            hour: '2-digit',
                            minute: '2-digit'
                          })}
                        </span>
                      </div>
                    </div>
                    
                    <div class="item-actions">
                      <button
                        onClick={() => handleEditItem(item)}
                        class="item-btn item-btn-edit"
                        title="编辑项目"
                      >
                        <span class="btn-icon">✏️</span>
                      </button>
                      <button
                        onClick={() => handleDeleteItem(item.id)}
                        class="item-btn item-btn-delete"
                        title="删除项目"
                      >
                        <span class="btn-icon">🗑️</span>
                      </button>
                    </div>
                  </div>
                )}
              </For>
            </div>

            {/* 分页信息 */}
            <Show when={crud.state.total > 0}>
              <div class="crud-pagination">
                <div class="pagination-info">
                  <span class="pagination-stats">
                    显示 {crud.state.items.length} 项，共 {crud.state.total} 项
                  </span>
                  <Show when={crud.totalPages() > 1}>
                    <span class="pagination-pages">
                      第 {crud.state.currentPage} 页，共 {crud.totalPages()} 页
                    </span>
                  </Show>
                </div>
                
                <Show when={crud.totalPages() > 1}>
                  <div class="pagination-controls">
                    <button
                      onClick={() => crud.prevPage()}
                      disabled={crud.state.currentPage <= 1}
                      class="pagination-btn"
                      title="上一页"
                    >
                      <span class="btn-icon">⬅️</span>
                    </button>
                    <span class="pagination-current">
                      {crud.state.currentPage} / {crud.totalPages()}
                    </span>
                    <button
                      onClick={() => crud.nextPage()}
                      disabled={crud.state.currentPage >= crud.totalPages()}
                      class="pagination-btn"
                      title="下一页"
                    >
                      <span class="btn-icon">➡️</span>
                    </button>
                  </div>
                </Show>
              </div>
            </Show>
          </div>
        </Show>
      </Show>
    </div>
  );
} 