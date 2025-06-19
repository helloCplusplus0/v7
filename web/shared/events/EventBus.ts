// shared/events/EventBus.ts - 零依赖事件总线
import type { EventMap, EventHandler, Unsubscribe } from './events.types';

class EventBus {
  private listeners = new Map<keyof EventMap, Set<Function>>();
  
  // 发布事件 - 发布者不知道谁在监听
  emit<K extends keyof EventMap>(event: K, data: EventMap[K]): void {
    const handlers = this.listeners.get(event);
    if (handlers) {
      handlers.forEach(handler => {
        try {
          handler(data);
        } catch (error) {
          console.error(`Event handler error for ${String(event)}:`, error);
        }
      });
    }
  }
  
  // 订阅事件 - 订阅者不知道谁在发布
  on<K extends keyof EventMap>(
    event: K, 
    handler: EventHandler<K>
  ): Unsubscribe {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
    
    // 返回取消订阅函数
    return () => this.off(event, handler);
  }
  
  // 取消订阅
  off<K extends keyof EventMap>(event: K, handler?: Function): void {
    if (handler) {
      this.listeners.get(event)?.delete(handler);
    } else {
      // 如果没有指定handler，移除所有监听器
      this.listeners.delete(event);
    }
  }
  
  // 一次性监听
  once<K extends keyof EventMap>(
    event: K, 
    handler: EventHandler<K>
  ): void {
    const onceHandler = (data: EventMap[K]) => {
      handler(data);
      this.off(event, onceHandler);
    };
    this.on(event, onceHandler);
  }
  
  // 清理所有监听器 - 主要用于测试
  removeAllListeners(): void {
    this.listeners.clear();
  }
}

export const eventBus = new EventBus();

// 类型定义 - 用于其他文件
export type { EventMap }; 