// 🎨 MVP CRUD - UI组件实现
// 遵循Web v7架构规范：SolidJS细粒度响应式 + 现代化UI设计

import { createSignal, createMemo, For, Show, onMount, Suspense, lazy } from 'solid-js';
import { useCrud, useItemForm } from './hooks';
import type { Item, CreateItemRequest, CrudViewProps, ItemCardProps, ItemFormProps } from './types';
import './styles.css'; // 引入切片独立样式

// 导入集成测试（开发环境）
// 集成测试已移除

// ===== 子组件定义 =====

/**
 * 项目卡片组件 - 细粒度响应式
 */
const ItemCard = (props: ItemCardProps) => {
  return (
    <div 
      class={`item-card ${props.selected ? 'selected' : ''} ${props.className || ''}`}
      onClick={() => props.onSelect?.(props.item)}
    >
      <div class="item-header">
        <h3 class="item-name">{props.item.name}</h3>
        <div class="item-actions">
          <button
            onClick={(e) => {
              e.stopPropagation();
              props.onEdit?.(props.item);
            }}
            class="action-btn edit-btn"
            title="编辑项目"
          >
            ✏️
          </button>
          <button
            onClick={(e) => {
              e.stopPropagation();
              props.onDelete?.(props.item);
            }}
            class="action-btn delete-btn"
            title="删除项目"
          >
            🗑️
          </button>
        </div>
      </div>
      
      <Show when={props.item.description}>
        <p class="item-description">{props.item.description}</p>
      </Show>
      
      <div class="item-meta">
        <div class="item-value">
          <span class="value-label">值:</span>
          <span class="value-number">{props.item.value}</span>
        </div>
        <div class="item-dates">
          <div class="date-item">
            <span class="date-label">创建:</span>
            <span class="date-value">{new Date(props.item.createdAt).toLocaleDateString()}</span>
          </div>
          <div class="date-item">
            <span class="date-label">更新:</span>
            <span class="date-value">{new Date(props.item.updatedAt).toLocaleDateString()}</span>
          </div>
        </div>
      </div>
    </div>
  );
};

/**
 * 项目表单组件 - 独立的表单逻辑
 */
const ItemForm = (props: ItemFormProps) => {
  const form = useItemForm(props.item ? {
    name: props.item.name,
    description: props.item.description || '',
    value: props.item.value
  } : undefined);

  const handleSubmit = async (e: Event) => {
    e.preventDefault();
    const success = await form.submit(props.onSubmit);
    if (success) {
      props.onCancel();
    }
  };

  return (
    <div class={`item-form-overlay ${props.className || ''}`}>
      <div class="item-form-container">
        <div class="form-header">
          <h2 class="form-title">
            {props.item ? '编辑项目' : '创建新项目'}
          </h2>
          <button
            onClick={props.onCancel}
            class="form-close-btn"
            title="关闭表单"
          >
            ✕
          </button>
        </div>
        
        <form onSubmit={handleSubmit} class="item-form">
          <div class="form-field">
            <label for="item-name" class="field-label">项目名称 *</label>
            <input
              id="item-name"
              type="text"
              value={form.formData.name}
              onInput={(e) => form.updateField('name', e.currentTarget.value)}
              placeholder="请输入项目名称"
              class={`field-input ${form.errors().name ? 'error' : ''}`}
              disabled={form.submitting()}
            />
            <Show when={form.errors().name}>
              <span class="field-error">{form.errors().name}</span>
            </Show>
          </div>

          <div class="form-field">
            <label for="item-description" class="field-label">项目描述</label>
            <textarea
              id="item-description"
              value={form.formData.description}
              onInput={(e) => form.updateField('description', e.currentTarget.value)}
              placeholder="请输入项目描述（可选）"
              class={`field-textarea ${form.errors().description ? 'error' : ''}`}
              rows="3"
              disabled={form.submitting()}
            />
            <Show when={form.errors().description}>
              <span class="field-error">{form.errors().description}</span>
            </Show>
          </div>

          <div class="form-field">
            <label for="item-value" class="field-label">项目值 *</label>
            <input
              id="item-value"
              type="number"
              value={form.formData.value}
              onInput={(e) => form.updateField('value', Number(e.currentTarget.value))}
              placeholder="请输入项目值"
              class={`field-input ${form.errors().value ? 'error' : ''}`}
              min="0"
              disabled={form.submitting()}
            />
            <Show when={form.errors().value}>
              <span class="field-error">{form.errors().value}</span>
            </Show>
          </div>

          <div class="form-actions">
            <button
              type="button"
              onClick={props.onCancel}
              class="btn btn-secondary"
              disabled={form.submitting()}
            >
              取消
            </button>
            <button
              type="submit"
              class="btn btn-primary"
              disabled={!form.canSubmit()}
            >
              <Show 
                when={!form.submitting()} 
                fallback={<span>提交中...</span>}
              >
                {props.item ? '更新' : '创建'}
              </Show>
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

/**
 * 空状态组件
 */
const EmptyState = () => (
  <div class="empty-state">
    <div class="empty-icon">📋</div>
    <h3 class="empty-title">暂无项目</h3>
    <p class="empty-description">点击"创建项目"按钮开始添加您的第一个项目</p>
  </div>
);

/**
 * 加载状态组件
 */
const LoadingState = () => (
  <div class="loading-state">
    <div class="loading-spinner"></div>
    <p class="loading-text">加载中...</p>
  </div>
);

/**
 * 错误状态组件
 */
const ErrorState = (props: { error: string; onRetry: () => void }) => (
  <div class="error-state">
    <div class="error-icon">⚠️</div>
    <h3 class="error-title">加载失败</h3>
    <p class="error-message">{props.error}</p>
    <button onClick={props.onRetry} class="btn btn-primary">
      重试
    </button>
  </div>
);

// ===== 主组件 =====

/**
 * CRUD视图主组件
 * 使用SolidJS细粒度响应式，最小化重新渲染
 */
export function CrudView(props: CrudViewProps = {}) {
  const crud = useCrud();
  
  // 本地UI状态
  const [showCreateForm, setShowCreateForm] = createSignal(false);
  const [editingItem, setEditingItem] = createSignal<Item | null>(null);
  const [viewMode, setViewMode] = createSignal<'grid' | 'list'>('grid');

  // 计算属性 - 细粒度响应式
  const currentStats = createMemo(() => {
    const itemsList = crud.items();
    const total = itemsList.length;
    const average = total > 0 ? Math.round(itemsList.reduce((sum, item) => sum + item.value, 0) / total) : 0;
    const maxValue = total > 0 ? Math.max(...itemsList.map(item => item.value)) : 0;
    return { total, average, maxValue };
  });

  const canShowBulkActions = createMemo(() => crud.hasSelection());
  const paginationInfo = createMemo(() => ({
    current: crud.currentPage(),
    total: crud.totalPages(),
    hasNext: crud.currentPage() < crud.totalPages(),
    hasPrev: crud.currentPage() > 1
  }));

  // 页面加载时自动加载数据
  onMount(() => {
    crud.loadItems();
  });

  // 事件处理函数
  const handleCreateItem = async (data: CreateItemRequest) => {
    await crud.createItem(data);
    setShowCreateForm(false);
  };

  const handleUpdateItem = async (data: CreateItemRequest) => {
    const item = editingItem();
    if (!item) return;
    
    await crud.updateItem(item.id, data);
    setEditingItem(null);
  };

  const handleDeleteItem = async (item: Item) => {
    if (confirm(`确定要删除项目"${item.name}"吗？`)) {
      await crud.deleteItem(item.id);
    }
  };

  const handleItemSelect = (item: Item) => {
    crud.setSelectedItem(item);
    props.onItemSelect?.(item);
  };

  const handleBulkDelete = async () => {
    const count = crud.selectedCount();
    if (confirm(`确定要删除选中的 ${count} 个项目吗？`)) {
      await crud.deleteSelectedItems();
    }
  };

  return (
    <div class={`crud-container ${props.className || ''}`}>
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
            disabled={crud.loading()}
            class="btn btn-secondary"
            title="刷新数据"
          >
            <span class="btn-icon">{crud.loading() ? '🔄' : '↻'}</span>
            刷新
          </button>
          
          <Show when={props.showSearch !== false}>
            <div class="search-container">
              <input
                type="text"
                placeholder="搜索项目..."
                value={crud.searchTerm()}
                onInput={(e) => crud.setSearchTerm(e.currentTarget.value)}
                class="search-input"
              />
              <Show when={crud.searchTerm()}>
                <button
                  onClick={() => crud.clearSearch()}
                  class="search-clear"
                  title="清除搜索"
                >
                  ✕
                </button>
              </Show>
            </div>
          </Show>
          
          <Show when={crud.hasItems()}>
            <div class="view-controls">
              <button
                onClick={() => setViewMode('grid')}
                class={`view-btn ${viewMode() === 'grid' ? 'active' : ''}`}
                title="网格视图"
              >
                ⊞
              </button>
              <button
                onClick={() => setViewMode('list')}
                class={`view-btn ${viewMode() === 'list' ? 'active' : ''}`}
                title="列表视图"
              >
                ☰
              </button>
            </div>
          </Show>
        </div>
        
        <div class="crud-actions-right">
          <Show when={canShowBulkActions()}>
            <div class="bulk-actions">
              <span class="selection-info">
                已选中 {crud.selectedCount()} 项
              </span>
              <button
                onClick={handleBulkDelete}
                class="btn btn-danger btn-sm"
                title="批量删除"
              >
                🗑️ 删除
              </button>
            </div>
          </Show>
          
          <Show when={props.showCreateButton !== false}>
            <button
              onClick={() => setShowCreateForm(true)}
              class="btn btn-primary"
              title="创建新项目"
            >
              <span class="btn-icon">✨</span>
              创建项目
            </button>
          </Show>
        </div>
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

      {/* 主内容区域 */}
      <div class="crud-content">
        <Show 
          when={!crud.loading()} 
          fallback={<LoadingState />}
        >
          <Show 
            when={!crud.error()}
            fallback={<ErrorState error={crud.error()!} onRetry={() => crud.refresh()} />}
          >
            <Show 
              when={crud.hasItems()}
              fallback={<EmptyState />}
            >
              {/* 批量选择控制 */}
              <Show when={crud.hasItems()}>
                <div class="bulk-controls">
                  <label class="bulk-checkbox">
                                         <input
                       type="checkbox"
                       checked={crud.selectedCount() === crud.items().length}
                       ref={(el) => {
                         if (el) {
                           el.indeterminate = crud.hasSelection() && crud.selectedCount() < crud.items().length;
                         }
                       }}
                       onChange={() => crud.toggleSelectAll()}
                     />
                    <span class="checkbox-label">
                      {crud.hasSelection() ? `已选中 ${crud.selectedCount()} 项` : '全选'}
                    </span>
                  </label>
                  
                  <div class="sort-controls">
                    <label class="sort-label">排序:</label>
                    <select 
                      class="sort-select"
                      value={crud.sortField()}
                      onChange={(e) => crud.sort(e.currentTarget.value as any)}
                    >
                      <option value="created_at">创建时间</option>
                      <option value="updated_at">更新时间</option>
                      <option value="name">名称</option>
                      <option value="value">数值</option>
                    </select>
                    <button
                      onClick={() => crud.sort(crud.sortField())}
                      class="sort-order-btn"
                      title={`当前: ${crud.sortOrder() === 'asc' ? '升序' : '降序'}`}
                    >
                      {crud.sortOrder() === 'asc' ? '↑' : '↓'}
                    </button>
                  </div>
                </div>
              </Show>

              {/* 项目列表 */}
              <div class={`items-container ${viewMode()}-view`}>
                <For each={crud.items()}>
                  {(item) => (
                    <div class="item-wrapper">
                      <label class="item-checkbox">
                        <input
                          type="checkbox"
                          checked={crud.selectedIds().includes(item.id)}
                          onChange={() => crud.toggleSelection(item.id)}
                        />
                      </label>
                      <ItemCard
                        item={item}
                        selected={crud.selectedItem()?.id === item.id}
                        onSelect={handleItemSelect}
                        onEdit={(item) => setEditingItem(item)}
                        onDelete={handleDeleteItem}
                      />
                    </div>
                  )}
                </For>
              </div>

              {/* 分页控制 */}
              <Show when={crud.totalPages() > 1}>
                <div class="pagination">
                  <div class="pagination-info">
                    第 {crud.currentPage()} 页，共 {crud.totalPages()} 页
                    （总计 {crud.total()} 项）
                  </div>
                  
                  <div class="pagination-controls">
                    <button
                      onClick={() => crud.prevPage()}
                      disabled={!paginationInfo().hasPrev}
                      class="pagination-btn"
                    >
                      ← 上一页
                    </button>
                    
                    <div class="page-numbers">
                      <For each={Array.from({ length: Math.min(5, crud.totalPages()) }, (_, i) => {
                        const start = Math.max(1, crud.currentPage() - 2);
                        return start + i;
                      }).filter(page => page <= crud.totalPages())}>
                        {(page) => (
                          <button
                            onClick={() => crud.goToPage(page)}
                            class={`page-btn ${page === crud.currentPage() ? 'active' : ''}`}
                          >
                            {page}
                          </button>
                        )}
                      </For>
                    </div>
                    
                    <button
                      onClick={() => crud.nextPage()}
                      disabled={!paginationInfo().hasNext}
                      class="pagination-btn"
                    >
                      下一页 →
                    </button>
                  </div>
                  
                  <div class="page-size-control">
                    <label>每页显示:</label>
                    <select
                      value={crud.pageSize()}
                      onChange={(e) => crud.changePageSize(Number(e.currentTarget.value))}
                      class="page-size-select"
                    >
                      <option value="5">5</option>
                      <option value="10">10</option>
                      <option value="20">20</option>
                      <option value="50">50</option>
                    </select>
                  </div>
                </div>
              </Show>
            </Show>
          </Show>
        </Show>
      </div>

      {/* 创建表单弹窗 */}
      <Show when={showCreateForm()}>
        <ItemForm
          onSubmit={handleCreateItem}
          onCancel={() => setShowCreateForm(false)}
        />
      </Show>

      {/* 编辑表单弹窗 */}
      <Show when={editingItem()}>
        <ItemForm
          item={editingItem()!}
          onSubmit={handleUpdateItem}
          onCancel={() => setEditingItem(null)}
        />
      </Show>
    </div>
  );
}

// 默认导出
export default CrudView; 