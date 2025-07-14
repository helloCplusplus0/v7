/**
 * 🎯 v7 Web架构 - 切片注册表
 * 统一管理所有功能切片的注册和访问
 */

import type { SliceRegistry, SliceRegistration } from './types';

// 导入摘要提供者
import { mvpCrudSummaryProvider } from '../../slices/mvp_crud/summaryProvider';

// 统一的切片注册表
export const sliceRegistry: SliceRegistry = {
  mvp_crud: {
    name: 'mvp_crud',
    displayName: 'MVP CRUD',
    path: '/mvp_crud',
    description: 'MVP CRUD功能演示',
    version: '1.0.0',
    componentLoader: () => import('../../slices/mvp_crud'),
    summaryProvider: mvpCrudSummaryProvider
  }
};

// 辅助函数
export const getSliceNames = (): string[] => Object.keys(sliceRegistry);

export const getSliceRegistration = (name: string): SliceRegistration => {
  const slice = sliceRegistry[name];
  if (!slice) {
    throw new Error(`切片 "${name}" 未找到`);
  }
  return slice;
};

export const getSliceComponent = (name: string) => {
  return getSliceRegistration(name).componentLoader;
};

export const getSliceMetadata = (name: string) => {
  const slice = getSliceRegistration(name);
  return {
    name: slice.name,
    displayName: slice.displayName,
    path: slice.path,
    description: slice.description,
    version: slice.version
  };
};

export const getSliceSummaryProvider = (name: string) => {
  return getSliceRegistration(name).summaryProvider;
};

export const hasSlice = (name: string): boolean => name in sliceRegistry;

export const getAllSliceRegistrations = (): SliceRegistration[] => 
  Object.values(sliceRegistry);