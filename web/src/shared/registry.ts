/**
 * 切片注册表 - 统一管理切片组件和摘要提供者
 * 自动生成，请勿手动修改
 * 
 * 此文件由 fmod 工具自动维护
 * 每次添加或删除切片时会自动更新
 */

import { lazy, Component } from 'solid-js';
import type { SliceRegistry, SliceRegistration } from './types';

// 导入摘要提供者
import { mvpCrudSummaryProvider } from '../../slices/mvp_crud/summaryProvider';

// 统一的切片注册表
export const sliceRegistry: SliceRegistry = {
  mvp_crud: {
    name: 'mvp_crud',
    displayName: 'MVP CRUD',
    path: '/mvp_crud',
    description: 'MVP CRUD 管理切片',
    version: '1.0.0',
    componentLoader: () => import('../../slices/mvp_crud'),
    summaryProvider: mvpCrudSummaryProvider,
  },
};

// 兼容性API - 保持向后兼容
export const slices: Record<string, () => Promise<{ default: Component }>> = 
  Object.fromEntries(
    Object.entries(sliceRegistry).map(([key, registration]) => [
      key, 
      registration.componentLoader
    ])
  );

export const sliceMetadata = 
  Object.fromEntries(
    Object.entries(sliceRegistry).map(([key, registration]) => [
      key,
      {
        name: registration.name,
        displayName: registration.displayName,
        path: registration.path,
        description: registration.description,
        version: registration.version,
      }
    ])
  );

// 新的统一API
export const getSliceNames = (): string[] => Object.keys(sliceRegistry);

export const getSliceRegistration = (name: string): SliceRegistration => {
  const registration = sliceRegistry[name];
  if (!registration) {
    throw new Error(`Slice "${name}" not found in registry`);
  }
  return registration;
};

export const getSliceComponent = (name: string) => {
  const registration = getSliceRegistration(name);
  return lazy(registration.componentLoader);
};

export const getSliceMetadata = (name: string) => {
  const registration = getSliceRegistration(name);
  return {
    name: registration.name,
    displayName: registration.displayName,
    path: registration.path,
    description: registration.description,
    version: registration.version,
  };
};

export const getSliceSummaryProvider = (name: string) => {
  const registration = getSliceRegistration(name);
  return registration.summaryProvider;
};

export const hasSlice = (name: string): boolean => name in sliceRegistry;

export const getAllSliceRegistrations = (): SliceRegistration[] => 
  Object.values(sliceRegistry);