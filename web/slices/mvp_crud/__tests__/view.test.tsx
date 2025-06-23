// 🧪 MVP CRUD - UI组件测试
// 测试现代化UI组件的渲染和交互功能

import { describe, test, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@solidjs/testing-library';
import { CrudView } from '../view';
import type { Item } from '../types';

// Mock hooks
const mockCrud = {
  state: {
    items: [] as Item[],
    total: 0,
    currentPage: 1,
    loading: false,
    error: null,
  },
  isLoading: () => false,
  hasItems: () => false,
  error: () => null,
  loadItems: vi.fn(),
  createItem: vi.fn(),
  updateItem: vi.fn(),
  deleteItem: vi.fn(),
  refresh: vi.fn(),
  sort: vi.fn(),
  clearError: vi.fn(),
  totalPages: () => 1,
  prevPage: vi.fn(),
  nextPage: vi.fn(),
};

vi.mock('../hooks', () => ({
  useCrud: () => mockCrud,
}));

describe('CrudView 组件测试', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockCrud.state.items = [];
    mockCrud.state.total = 0;
    mockCrud.hasItems = () => false;
  });

  test('应该正确渲染页面头部', () => {
    render(() => <CrudView />);
    
    expect(screen.getByText('项目管理')).toBeInTheDocument();
    expect(screen.getByText('管理和组织您的项目，提升工作效率')).toBeInTheDocument();
    expect(screen.getByText('总项目')).toBeInTheDocument();
  });

  test('应该正确显示空状态', () => {
    render(() => <CrudView />);
    
    expect(screen.getByText('暂无项目')).toBeInTheDocument();
    expect(screen.getByText('还没有创建任何项目，点击下方按钮开始创建您的第一个项目。')).toBeInTheDocument();
    expect(screen.getByText('创建第一个项目')).toBeInTheDocument();
  });

  test('应该正确渲染项目列表', () => {
    const mockItems: Item[] = [
      {
        id: '1',
        name: '测试项目1',
        description: '这是一个测试项目',
        value: 100,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      },
      {
        id: '2',
        name: '测试项目2',
        value: 200,
        created_at: '2024-01-02T00:00:00Z',
        updated_at: '2024-01-02T00:00:00Z',
      },
    ];

    mockCrud.state.items = mockItems;
    mockCrud.state.total = 2;
    mockCrud.hasItems = () => true;

    render(() => <CrudView />);
    
    expect(screen.getByText('测试项目1')).toBeInTheDocument();
    expect(screen.getByText('测试项目2')).toBeInTheDocument();
    expect(screen.getByText('这是一个测试项目')).toBeInTheDocument();
    expect(screen.getByText('100')).toBeInTheDocument();
    expect(screen.getByText('200')).toBeInTheDocument();
  });

  test('应该正确显示统计信息', () => {
    const mockItems: Item[] = [
      {
        id: '1',
        name: '项目1',
        value: 100,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      },
      {
        id: '2',
        name: '项目2',
        value: 200,
        created_at: '2024-01-01T00:00:00Z',
        updated_at: '2024-01-01T00:00:00Z',
      },
    ];

    mockCrud.state.items = mockItems;
    mockCrud.state.total = 2;
    mockCrud.hasItems = () => true;

    render(() => <CrudView />);
    
    // 检查统计信息
    expect(screen.getByText('2')).toBeInTheDocument(); // 总项目数
    expect(screen.getByText('150')).toBeInTheDocument(); // 平均值 (100+200)/2 = 150
    expect(screen.getByText('200')).toBeInTheDocument(); // 最大值
  });

  test('应该处理表单输入', () => {
    render(() => <CrudView />);
    
    // 点击创建按钮
    const createButton = screen.getByText('创建项目');
    fireEvent.click(createButton);
    
    // 检查表单是否打开
    expect(screen.getByText('创建新项目')).toBeInTheDocument();
    
    // 输入项目名称
    const nameInput = screen.getByPlaceholderText('请输入有意义的项目名称');
    fireEvent.input(nameInput, { target: { value: '新项目' } });
    
    // 输入项目数值
    const valueInput = screen.getByPlaceholderText('请输入项目数值');
    fireEvent.input(valueInput, { target: { value: '500' } });
    
    // 输入描述
    const descInput = screen.getByPlaceholderText('描述项目的目标、内容或备注信息');
    fireEvent.input(descInput, { target: { value: '这是一个新项目' } });
    
    // 检查字符计数
    expect(screen.getByText('3/100 字符')).toBeInTheDocument();
    expect(screen.getByText('7/500 字符')).toBeInTheDocument();
  });

  test('应该处理表单提交', async () => {
    mockCrud.createItem.mockResolvedValue({});
    
    render(() => <CrudView />);
    
    // 打开表单
    fireEvent.click(screen.getByText('创建项目'));
    
    // 填写表单
    const nameInput = screen.getByPlaceholderText('请输入有意义的项目名称');
    const valueInput = screen.getByPlaceholderText('请输入项目数值');
    
    fireEvent.input(nameInput, { target: { value: '测试项目' } });
    fireEvent.input(valueInput, { target: { value: '100' } });
    
    // 提交表单
    const submitButton = screen.getByText('确认创建');
    fireEvent.click(submitButton);
    
    await waitFor(() => {
      expect(mockCrud.createItem).toHaveBeenCalledWith({
        name: '测试项目',
        value: 100,
      });
    });
  });

  test('应该处理错误状态', () => {
    mockCrud.error = () => '网络错误' as any;
    
    render(() => <CrudView />);
    
    expect(screen.getByText('网络错误')).toBeInTheDocument();
    
    // 点击关闭错误按钮
    const closeButton = screen.getByTitle('关闭错误提示');
    fireEvent.click(closeButton);
    
    expect(mockCrud.clearError).toHaveBeenCalled();
  });

  test('应该处理加载状态', () => {
    mockCrud.isLoading = () => true;
    
    render(() => <CrudView />);
    
    expect(screen.getByText('正在加载项目数据...')).toBeInTheDocument();
  });

  test('应该处理项目编辑', () => {
    const mockItem: Item = {
      id: '1',
      name: '测试项目',
      description: '测试描述',
      value: 100,
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    mockCrud.state.items = [mockItem];
    mockCrud.hasItems = () => true;
    
    render(() => <CrudView />);
    
    // 点击编辑按钮
    const editButton = screen.getByTitle('编辑项目');
    fireEvent.click(editButton);
    
    // 检查表单是否显示编辑模式
    expect(screen.getByText('编辑项目')).toBeInTheDocument();
    expect(screen.getByText('确认更新')).toBeInTheDocument();
    
    // 检查表单是否预填充了数据
    expect(screen.getByDisplayValue('测试项目')).toBeInTheDocument();
    expect(screen.getByDisplayValue('测试描述')).toBeInTheDocument();
    expect(screen.getByDisplayValue('100')).toBeInTheDocument();
  });

  test('应该处理项目删除', () => {
    // Mock window.confirm
    vi.spyOn(window, 'confirm').mockReturnValue(true);
    
    const mockItem: Item = {
      id: '1',
      name: '测试项目',
      value: 100,
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    mockCrud.state.items = [mockItem];
    mockCrud.hasItems = () => true;
    
    render(() => <CrudView />);
    
    // 点击删除按钮
    const deleteButton = screen.getByTitle('删除项目');
    fireEvent.click(deleteButton);
    
    expect(window.confirm).toHaveBeenCalledWith('确定要删除这个项目吗？');
    expect(mockCrud.deleteItem).toHaveBeenCalledWith('1');
  });

  test('应该处理排序', () => {
    mockCrud.state.total = 1;
    
    render(() => <CrudView />);
    
    // 点击排序选择器
    const sortSelect = screen.getByTitle('排序方式');
    fireEvent.change(sortSelect, { target: { value: 'name' } });
    
    expect(mockCrud.sort).toHaveBeenCalledWith('name');
  });

  test('应该处理刷新操作', () => {
    render(() => <CrudView />);
    
    // 点击刷新按钮
    const refreshButton = screen.getByTitle('刷新数据');
    fireEvent.click(refreshButton);
    
    expect(mockCrud.refresh).toHaveBeenCalled();
  });

  test('应该在页面加载时获取数据', () => {
    render(() => <CrudView />);
    
    expect(mockCrud.loadItems).toHaveBeenCalled();
  });

  test('应该正确处理数值格式化', () => {
    const mockItem: Item = {
      id: '1',
      name: '大数值项目',
      value: 123456,
      created_at: '2024-01-01T00:00:00Z',
      updated_at: '2024-01-01T00:00:00Z',
    };

    mockCrud.state.items = [mockItem];
    mockCrud.hasItems = () => true;
    
    render(() => <CrudView />);
    
    // 检查数值是否正确格式化（使用千分位分隔符）
    expect(screen.getByText('123,456')).toBeInTheDocument();
  });
}); 