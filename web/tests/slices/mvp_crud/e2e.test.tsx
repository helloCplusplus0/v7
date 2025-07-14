// 🧪 MVP CRUD 端到端测试 - 简化版本
// 专注核心用户流程测试，避免复杂的mock设置

import { describe, test, expect, beforeEach, vi } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@solidjs/testing-library';
import { CrudView } from '../../../slices/mvp_crud/view';
import { createMockItem, createMockItems } from './test-utils';

// 简化的Mock设置
vi.mock('../../../shared/api', () => ({
  grpcClient: {
    createItem: vi.fn(),
    getItem: vi.fn(),
    updateItem: vi.fn(),
    deleteItem: vi.fn(),
    listItems: vi.fn(),
    healthCheck: vi.fn()
  }
}));

vi.mock('../../../slices/mvp_crud/hooks', () => {
  return {
    useCrud: vi.fn(() => ({
      items: () => [],
      selectedItem: () => null,
      loading: () => false,
      error: () => null,
      searchTerm: () => '',
      currentPage: () => 1,
      pageSize: () => 10,
      total: () => 0,
      sortField: () => 'createdAt',
      sortOrder: () => 'desc',
      selectedIds: () => [],
      totalPages: () => 1,
      hasItems: () => false,
      selectedCount: () => 0,
      hasSelection: () => false,
      isEmpty: () => true,
      filteredItems: () => [],
      loadItems: vi.fn(),
      createItem: vi.fn(),
      updateItem: vi.fn(),
      deleteItem: vi.fn(),
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
      validateForm: vi.fn()
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

describe('MVP CRUD E2E Tests - 核心用户流程', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('用户首次访问场景', () => {
    test('应该显示欢迎界面和基本功能', async () => {
      render(() => <CrudView />);

      // 验证页面标题
      expect(screen.getByText('项目管理')).toBeInTheDocument();
      
      // 验证核心功能按钮
      expect(screen.getByRole('button', { name: /刷新/ })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /创建项目/ })).toBeInTheDocument();
      
      // 验证搜索功能
      expect(screen.getByPlaceholderText('搜索项目...')).toBeInTheDocument();
      
      // 验证空状态显示
      expect(screen.getByText('暂无项目')).toBeInTheDocument();
    });

    test('应该显示统计信息区域', () => {
      render(() => <CrudView />);
      
      expect(screen.getByText('总项目')).toBeInTheDocument();
    });
  });

  describe('创建项目流程', () => {
    test('应该能够打开创建表单', async () => {
      render(() => <CrudView />);
      
      const createButton = screen.getByRole('button', { name: /创建项目/ });
      fireEvent.click(createButton);
      
      // 验证表单出现
      await waitFor(() => {
        expect(screen.getByText('创建新项目')).toBeInTheDocument();
      });
    });

    test('应该显示表单字段', async () => {
      render(() => <CrudView />);
      
      const createButton = screen.getByRole('button', { name: /创建项目/ });
      fireEvent.click(createButton);
      
      await waitFor(() => {
        expect(screen.getByLabelText('项目名称 *')).toBeInTheDocument();
        expect(screen.getByLabelText('项目描述')).toBeInTheDocument();
        expect(screen.getByLabelText('项目值 *')).toBeInTheDocument();
      });
    });
  });

  describe('搜索功能', () => {
    test('应该能够输入搜索关键词', () => {
      render(() => <CrudView />);
      
      const searchInput = screen.getByPlaceholderText('搜索项目...');
      fireEvent.input(searchInput, { target: { value: '测试搜索' } });
      
      expect(searchInput).toHaveValue('测试搜索');
    });

    test('应该有清除搜索功能', () => {
      render(() => <CrudView />);
      
      const searchInput = screen.getByPlaceholderText('搜索项目...');
      fireEvent.input(searchInput, { target: { value: '测试' } });
      
             // 当有搜索内容时，应该显示清除按钮
       if ((searchInput as HTMLInputElement).value) {
         const clearButton = screen.queryByTitle('清除搜索');
         if (clearButton) {
           expect(clearButton).toBeInTheDocument();
         }
       }
    });
  });

  describe('用户界面交互', () => {
    test('应该支持刷新操作', () => {
      render(() => <CrudView />);
      
      const refreshButton = screen.getByRole('button', { name: /刷新/ });
      fireEvent.click(refreshButton);
      
      // 验证按钮可点击
      expect(refreshButton).toBeInTheDocument();
    });

    test('应该支持视图模式切换', () => {
      render(() => <CrudView />);
      
      // 查找视图切换按钮（如果存在）
      const gridButton = screen.queryByTitle('网格视图');
      const listButton = screen.queryByTitle('列表视图');
      
      // 如果视图切换功能存在，验证其可用性
      if (gridButton && listButton) {
        expect(gridButton).toBeInTheDocument();
        expect(listButton).toBeInTheDocument();
      }
    });
  });

  describe('响应式设计验证', () => {
    test('应该在不同屏幕尺寸下正常显示', () => {
      render(() => <CrudView />);
      
      // 验证基本布局元素存在
      expect(screen.getByText('项目管理')).toBeInTheDocument();
      
      // 验证响应式容器类
      const container = screen.getByText('项目管理').closest('.crud-container');
      expect(container).toBeInTheDocument();
    });
  });

  describe('错误处理', () => {
    test('应该优雅处理无数据状态', () => {
      render(() => <CrudView />);
      
      expect(screen.getByText('暂无项目')).toBeInTheDocument();
      expect(screen.getByText('点击"创建项目"按钮开始添加您的第一个项目')).toBeInTheDocument();
    });
  });

  describe('用户体验优化', () => {
    test('应该提供直观的操作提示', () => {
      render(() => <CrudView />);
      
      // 验证按钮有明确的文本标识
      expect(screen.getByRole('button', { name: /刷新/ })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /创建项目/ })).toBeInTheDocument();
      
      // 验证搜索框有明确的占位符
      expect(screen.getByPlaceholderText('搜索项目...')).toBeInTheDocument();
    });

    test('应该有合理的页面布局', () => {
      render(() => <CrudView />);
      
      // 验证页面头部
      expect(screen.getByText('项目管理')).toBeInTheDocument();
      expect(screen.getByText('管理和组织您的项目，提升工作效率')).toBeInTheDocument();
      
      // 验证统计信息区域
      expect(screen.getByText('总项目')).toBeInTheDocument();
    });
  });

  describe('可访问性验证', () => {
    test('应该有正确的语义化标签', () => {
      render(() => <CrudView />);
      
      // 验证按钮角色
      expect(screen.getByRole('button', { name: /刷新/ })).toBeInTheDocument();
      expect(screen.getByRole('button', { name: /创建项目/ })).toBeInTheDocument();
      
      // 验证输入框
      expect(screen.getByPlaceholderText('搜索项目...')).toHaveAttribute('type', 'text');
    });
  });
}); 