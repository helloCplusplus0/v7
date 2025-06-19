// 🎨 MVP CRUD - UI组件实现
// 现代化、响应式的CRUD界面

import { createSignal, For, Show, onMount } from 'solid-js';
import { useCrud } from './hooks';
import type { Item, CreateItemRequest } from './types';

// 简化的CRUD视图组件
export function CrudView() {
  const crud = useCrud();
  const [showCreateForm, setShowCreateForm] = createSignal(false);
  const [newItemName, setNewItemName] = createSignal('');
  const [newItemValue, setNewItemValue] = createSignal(0);

  // 页面加载时获取数据
  onMount(() => {
    crud.loadItems();
  });

  const handleCreateItem = async () => {
    const data: CreateItemRequest = {
      name: newItemName(),
      value: newItemValue(),
    };

    try {
      await crud.createItem(data);
      setNewItemName('');
      setNewItemValue(0);
      setShowCreateForm(false);
    } catch (error) {
      console.error('创建失败:', error);
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

  return (
    <div class="p-6 max-w-6xl mx-auto">
      {/* 页面标题 */}
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">项目管理</h1>
        <p class="text-gray-600">管理和组织您的项目</p>
      </div>

      {/* 操作栏 */}
      <div class="mb-6 flex justify-between items-center">
        <button
          onClick={() => crud.refresh()}
          disabled={crud.isLoading()}
          class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600 disabled:opacity-50"
        >
          刷新
        </button>
        
        <button
          onClick={() => setShowCreateForm(true)}
          class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
        >
          创建项目
        </button>
      </div>

      {/* 错误提示 */}
      <Show when={crud.error()}>
        <div class="mb-4 p-4 bg-red-100 border border-red-400 text-red-700 rounded">
          {crud.error()}
          <button
            onClick={() => crud.clearError()}
            class="ml-2 underline"
          >
            关闭
          </button>
        </div>
      </Show>

      {/* 创建表单 */}
      <Show when={showCreateForm()}>
        <div class="mb-6 p-4 bg-gray-100 rounded">
          <h3 class="text-lg font-semibold mb-4">创建新项目</h3>
          <div class="space-y-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                项目名称
              </label>
              <input
                type="text"
                value={newItemName()}
                onInput={(e) => setNewItemName(e.currentTarget.value)}
                class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入项目名称"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                项目值
              </label>
              <input
                type="number"
                value={newItemValue()}
                onInput={(e) => setNewItemValue(parseInt(e.currentTarget.value) || 0)}
                class="w-full px-3 py-2 border border-gray-300 rounded focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入项目值"
              />
            </div>
            <div class="flex space-x-2">
              <button
                onClick={handleCreateItem}
                disabled={!newItemName().trim() || crud.isLoading()}
                class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50"
              >
                创建
              </button>
              <button
                onClick={() => setShowCreateForm(false)}
                class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
              >
                取消
              </button>
            </div>
          </div>
        </div>
      </Show>

      {/* 加载状态 */}
      <Show when={crud.isLoading()}>
        <div class="text-center py-8">
          <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
          <p class="mt-2 text-gray-600">加载中...</p>
        </div>
      </Show>

      {/* 项目列表 */}
      <Show when={!crud.isLoading()}>
        <Show 
          when={crud.hasItems()}
          fallback={
            <div class="text-center py-8">
              <p class="text-gray-500">暂无项目</p>
              <button
                onClick={() => setShowCreateForm(true)}
                class="mt-2 text-blue-500 hover:text-blue-700"
              >
                创建第一个项目
              </button>
            </div>
          }
        >
          <div class="bg-white shadow rounded-lg overflow-hidden">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    项目名称
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    项目值
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    创建时间
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    操作
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <For each={crud.state.items}>
                  {(item: Item) => (
                    <tr class="hover:bg-gray-50">
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="text-sm font-medium text-gray-900">{item.name}</div>
                        <Show when={item.description}>
                          <div class="text-sm text-gray-500">{item.description}</div>
                        </Show>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="text-sm text-gray-900">{item.value}</div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap">
                        <div class="text-sm text-gray-600">
                          {new Date(item.created_at).toLocaleString()}
                        </div>
                      </td>
                      <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                        <button
                          onClick={() => handleDeleteItem(item.id)}
                          class="text-red-600 hover:text-red-900"
                        >
                          删除
                        </button>
                      </td>
                    </tr>
                  )}
                </For>
              </tbody>
            </table>

            {/* 分页信息 */}
            <div class="bg-white px-4 py-3 border-t border-gray-200">
              <div class="flex items-center justify-between">
                <div class="text-sm text-gray-700">
                  共 {crud.state.total} 个项目
                </div>
                <div class="text-sm text-gray-700">
                  第 {crud.state.currentPage} 页，共 {crud.totalPages()} 页
                </div>
              </div>
            </div>
          </div>
        </Show>
      </Show>
    </div>
  );
} 