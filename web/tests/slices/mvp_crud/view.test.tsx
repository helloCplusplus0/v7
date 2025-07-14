// 🧪 MVP CRUD UI组件单元测试 - 简化版本
// 专注核心功能测试，避免复杂的边缘用例

import { describe, test, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@solidjs/testing-library';
import { createSignal } from 'solid-js';
import { CrudView } from '../../../slices/mvp_crud/view';
import { createMockItem, createMockItems } from './test-utils';

// 简化的Mock hooks
vi.mock('../../../slices/mvp_crud/hooks', () => {
  const [items, setItems] = createSignal([]);
  const [loading, setLoading] = createSignal(false);
  const [error, setError] = createSignal(null);
  
  return {
    useCrud: vi.fn(() => ({
      items: () => items(),
      selectedItem: () => null,
      loading: () => loading(),
      error: () => error(),
      searchTerm: () => '',
      currentPage: () => 1,
      pageSize: () => 10,
      total: () => 0,
      sortField: () => 'createdAt',
      sortOrder: () => 'desc',
      selectedIds: () => [],
      totalPages: () => 1,
      hasItems: () => items().length > 0,
      selectedCount: () => 0,
      hasSelection: () => false,
      isEmpty: () => items().length === 0 && !loading(),
      filteredItems: () => items(),
      loadItems: vi.fn(),
      createItem: vi.fn(),
      updateItem: vi.fn(),
      deleteItem: vi.fn(),
      getItem: vi.fn(),
      deleteSelectedItems: vi.fn(),
      toggleSelection: vi.fn(),
      toggleSelectAll: vi.fn(),
      sort: vi.fn(),
      goToPage: vi.fn(),
      nextPage: vi.fn(),
      prevPage: vi.fn(),
      changePageSize: vi.fn(),
      setSearchTerm: vi.fn(),
      clearSearch: vi.fn(),
      refresh: vi.fn(),
      clearError: vi.fn(),
      setSelectedItem: vi.fn(),
      validateForm: vi.fn(),
      // 测试辅助方法
      _setItems: setItems,
      _setLoading: setLoading,
      _setError: setError
    })),
    useItemForm: vi.fn(() => ({
      formData: { name: '', description: '', value: 0 },
      errors: () => ({}),
      touched: () => ({}),
      submitting: () => false,
      isValid: () => true,
      hasErrors: () => false,
      canSubmit: () => true,
      updateField: vi.fn(),
      reset: vi.fn(),
      validate: vi.fn(),
      submit: vi.fn()
    }))
  };
});

describe('CrudView Component - 核心功能测试', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('基础渲染', () => {
    test('应该渲染主要元素', () => {
      render(() => <CrudView />);
      
      expect(screen.getByText('项目管理')).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /刷新/ })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /创建项目/ })).toBeInTheDocument();
    });

    test('应该显示搜索框', () => {
      render(() => <CrudView />);
      
      expect(screen.getByPlaceholderText('搜索项目...')).toBeInTheDocument();
    });
  });

  describe('数据状态显示', () => {
    test('应该显示空状态', () => {
      render(() => <CrudView />);
      
      expect(screen.getByText('暂无项目')).toBeInTheDocument();
      expect(screen.getByText('点击"创建项目"按钮开始添加您的第一个项目')).toBeInTheDocument();
    });

    test('应该显示统计信息', () => {
      render(() => <CrudView />);
      
      // 验证统计信息区域存在
      expect(screen.getByText('总项目')).toBeInTheDocument();
    });
  });

  describe('用户交互', () => {
    test('应该有搜索输入框', () => {
      render(() => <CrudView />);
      
      const searchInput = screen.getByPlaceholderText('搜索项目...');
      expect(searchInput).toBeInTheDocument();
      expect(searchInput).toHaveAttribute('type', 'text');
    });

    test('应该有刷新按钮', () => {
      render(() => <CrudView />);
      
      const refreshButton = screen.getByRole('button', { name: /刷新/ });
      expect(refreshButton).toBeInTheDocument();
    });

    test('应该有创建按钮', () => {
      render(() => <CrudView />);
      
      const createButton = screen.getByRole('button', { name: /创建项目/ });
      expect(createButton).toBeInTheDocument();
    });
  });

  describe('Props 支持', () => {
    test('应该支持 className prop', () => {
      const { container } = render(() => <CrudView className="test-class" />);
      
      expect(container.firstChild).toHaveClass('test-class');
    });

    test('应该支持隐藏创建按钮', () => {
      render(() => <CrudView showCreateButton={false} />);
      
      expect(screen.queryByRole('button', { name: /创建项目/ })).not.toBeInTheDocument();
    });

    test('应该支持隐藏搜索框', () => {
      render(() => <CrudView showSearch={false} />);
      
      expect(screen.queryByPlaceholderText('搜索项目...')).not.toBeInTheDocument();
    });
  });

  describe('响应式设计', () => {
    test('应该有响应式CSS类', () => {
      const { container } = render(() => <CrudView />);
      
      expect(container.firstChild).toHaveClass('crud-container');
    });
  });
}); 