/**
 * 🎯 事件总线实现
 * 基于发布-订阅模式的全局事件管理系统
 */

import type { 
  GlobalEventMap, 
  EventHandler, 
  EventListenerConfig,
  EventName,
  EventData
} from './events.types';

/**
 * 事件监听器信息
 */
interface ListenerInfo {
  handler: EventHandler;
  once: boolean;
  priority: number;
  passive: boolean;
}

/**
 * 事件总线类
 * 实现高性能的事件发布-订阅系统
 */
class EventBus {
  private listeners: Map<EventName, ListenerInfo[]> = new Map();
  private maxListeners: number = 100;
  private debugMode: boolean = false;

  /**
   * 监听事件
   * @param event 事件名称
   * @param handler 事件处理器
   * @param config 监听器配置
   * @returns 取消监听的函数
   */
  on<K extends keyof GlobalEventMap>(
    event: K,
    handler: EventHandler<GlobalEventMap[K]>,
    config: EventListenerConfig = {}
  ): () => void {
    const { once = false, priority = 0, passive = false } = config;
    
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }

    const listeners = this.listeners.get(event)!;
    
    // 检查监听器数量限制
    if (listeners.length >= this.maxListeners) {
      console.warn(`[EventBus] 事件 "${event}" 的监听器数量已达到上限 ${this.maxListeners}`);
      return () => {};
    }

    const listenerInfo: ListenerInfo = {
      handler,
      once,
      priority,
      passive
    };

    // 按优先级插入监听器
    let insertIndex = listeners.length;
    for (let i = 0; i < listeners.length; i++) {
      if (listeners[i].priority < priority) {
        insertIndex = i;
        break;
      }
    }
    
    listeners.splice(insertIndex, 0, listenerInfo);

    if (this.debugMode) {
      console.log(`[EventBus] 添加监听器: ${event}, 优先级: ${priority}`);
    }

    // 返回取消监听函数
    return () => {
      this.off(event, handler);
    };
  }

  /**
   * 监听一次性事件
   * @param event 事件名称
   * @param handler 事件处理器
   * @returns 取消监听的函数
   */
  once<K extends keyof GlobalEventMap>(
    event: K,
    handler: EventHandler<GlobalEventMap[K]>
  ): () => void {
    return this.on(event, handler, { once: true });
  }

  /**
   * 发射事件
   * @param event 事件名称
   * @param data 事件数据
   */
  emit<K extends keyof GlobalEventMap>(
    event: K,
    data: GlobalEventMap[K]
  ): void {
    const listeners = this.listeners.get(event);
    if (!listeners || listeners.length === 0) {
      if (this.debugMode) {
        console.log(`[EventBus] 没有监听器处理事件: ${event}`);
      }
      return;
    }

    if (this.debugMode) {
      console.log(`[EventBus] 发射事件: ${event}`, data);
    }

    // 复制监听器数组，避免在执行过程中被修改
    const listenersToExecute = [...listeners];
    const toRemove: ListenerInfo[] = [];

    for (const listenerInfo of listenersToExecute) {
      try {
        // 执行监听器
        const result = listenerInfo.handler(data);
        
        // 处理异步监听器
        if (result instanceof Promise) {
          result.catch(error => {
            console.error(`[EventBus] 异步监听器执行失败 (${event}):`, error);
          });
        }

        // 标记一次性监听器为待移除
        if (listenerInfo.once) {
          toRemove.push(listenerInfo);
        }
      } catch (error) {
        console.error(`[EventBus] 监听器执行失败 (${event}):`, error);
        
        // 错误隔离：不重新抛出错误，确保其他监听器能正常执行
        // 如果需要严格的错误处理，可以通过passive配置控制
        if (!listenerInfo.passive) {
          // 在开发环境下记录错误，但不中断其他监听器的执行
          if (this.debugMode) {
            const errorMessage = error instanceof Error ? error.message : String(error);
            console.warn(`[EventBus] 非被动监听器出错，但已隔离处理: ${errorMessage}`);
          }
        }
      }
    }

    // 移除一次性监听器
    if (toRemove.length > 0) {
      const currentListeners = this.listeners.get(event)!;
      for (const listener of toRemove) {
        const index = currentListeners.indexOf(listener);
        if (index !== -1) {
          currentListeners.splice(index, 1);
        }
      }
    }
  }

  /**
   * 移除监听器
   * @param event 事件名称
   * @param handler 事件处理器（可选，如果不提供则移除所有监听器）
   */
  off<K extends keyof GlobalEventMap>(
    event: K,
    handler?: EventHandler<GlobalEventMap[K]>
  ): void {
    const listeners = this.listeners.get(event);
    if (!listeners) return;

    if (handler) {
      const index = listeners.findIndex(info => info.handler === handler);
      if (index !== -1) {
        listeners.splice(index, 1);
        
        if (this.debugMode) {
          console.log(`[EventBus] 移除监听器: ${event}`);
        }
      }
    } else {
      // 如果没有指定handler，移除所有监听器
      listeners.length = 0;
      
      if (this.debugMode) {
        console.log(`[EventBus] 移除所有监听器: ${event}`);
      }
    }

    // 如果没有监听器了，删除事件键
    if (listeners.length === 0) {
      this.listeners.delete(event);
    }
  }

  /**
   * 移除所有监听器
   * @param event 事件名称（可选）
   */
  removeAllListeners(event?: EventName): void {
    if (event) {
      this.listeners.delete(event);
      if (this.debugMode) {
        console.log(`[EventBus] 移除所有监听器: ${event}`);
      }
    } else {
      this.listeners.clear();
      if (this.debugMode) {
        console.log('[EventBus] 移除所有监听器');
      }
    }
  }

  /**
   * 获取监听器数量
   * @param event 事件名称
   * @returns 监听器数量
   */
  listenerCount(event: EventName): number {
    const listeners = this.listeners.get(event);
    return listeners ? listeners.length : 0;
  }

  /**
   * 获取所有事件名
   * @returns 事件名数组
   */
  eventNames(): EventName[] {
    return Array.from(this.listeners.keys());
  }

  /**
   * 检查是否有监听器
   * @param event 事件名称
   * @returns 是否有监听器
   */
  hasListeners(event: EventName): boolean {
    return this.listenerCount(event) > 0;
  }

  /**
   * 设置最大监听器数量
   * @param max 最大数量
   */
  setMaxListeners(max: number): void {
    this.maxListeners = Math.max(1, max);
  }

  /**
   * 获取最大监听器数量
   * @returns 最大监听器数量
   */
  getMaxListeners(): number {
    return this.maxListeners;
  }

  /**
   * 启用/禁用调试模式
   * @param enabled 是否启用
   */
  setDebugMode(enabled: boolean): void {
    this.debugMode = enabled;
  }

  /**
   * 获取调试模式状态
   * @returns 调试模式是否启用
   */
  isDebugMode(): boolean {
    return this.debugMode;
  }

  /**
   * 获取事件总线统计信息
   * @returns 统计信息
   */
  getStats(): {
    totalEvents: number;
    totalListeners: number;
    eventDetails: Array<{ event: EventName; listeners: number }>;
  } {
    const eventDetails: Array<{ event: EventName; listeners: number }> = [];
    let totalListeners = 0;

    for (const [event, listeners] of this.listeners) {
      const count = listeners.length;
      eventDetails.push({ event, listeners: count });
      totalListeners += count;
    }

    return {
      totalEvents: this.listeners.size,
      totalListeners,
      eventDetails
    };
  }

  /**
   * 清理事件总线
   * 移除所有监听器并重置状态
   */
  destroy(): void {
    this.listeners.clear();
    this.maxListeners = 100;
    this.debugMode = false;
    
    if (this.debugMode) {
      console.log('[EventBus] 事件总线已销毁');
    }
  }

  /**
   * 批量监听事件
   * @param events 事件映射
   * @returns 取消所有监听的函数
   */
  onMultiple<K extends keyof GlobalEventMap>(
    events: Partial<Record<K, EventHandler<GlobalEventMap[K]>>>
  ): () => void {
    const unsubscribers: Array<() => void> = [];

    for (const [event, handler] of Object.entries(events) as Array<[K, EventHandler<GlobalEventMap[K]>]>) {
      if (handler) {
        unsubscribers.push(this.on(event, handler));
      }
    }

    return () => {
      unsubscribers.forEach(unsubscribe => unsubscribe());
    };
  }

  /**
   * 等待特定事件
   * @param event 事件名称
   * @param timeout 超时时间（毫秒）
   * @returns Promise
   */
  waitFor<K extends keyof GlobalEventMap>(
    event: K,
    timeout?: number
  ): Promise<GlobalEventMap[K]> {
    return new Promise((resolve, reject) => {
      let timeoutId: NodeJS.Timeout | undefined;
      
      const unsubscribe = this.once(event, (data) => {
        if (timeoutId) {
          clearTimeout(timeoutId);
        }
        resolve(data);
      });

      if (timeout) {
        timeoutId = setTimeout(() => {
          unsubscribe();
          reject(new Error(`等待事件 "${event}" 超时`));
        }, timeout);
      }
    });
  }
}

// 创建全局事件总线实例
export const eventBus = new EventBus();

// 开发环境下启用调试模式
if (import.meta.env.DEV) {
  eventBus.setDebugMode(true);
  
  // 将事件总线暴露到全局，方便调试
  (globalThis as any).__eventBus = eventBus;
}

// 默认导出
export default eventBus;

// 类型导出
export type { EventBus, ListenerInfo };
export type { GlobalEventMap, EventHandler, EventListenerConfig } from './events.types'; 