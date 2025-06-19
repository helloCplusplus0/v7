// shared/providers/ContractProvider.tsx - 依赖注入容器
import { createContext, useContext } from 'solid-js';
import type { ContractMap } from '../contracts';

const ContractContext = createContext<ContractMap>({} as ContractMap);

export function ContractProvider(props: { 
  contracts: ContractMap;
  children: any;
}) {
  return (
    <ContractContext.Provider value={props.contracts}>
      {props.children}
    </ContractContext.Provider>
  );
}

// 类型安全的契约获取
export function useContract<K extends keyof ContractMap>(
  contractName: K
): ContractMap[K] {
  const contracts = useContext(ContractContext);
  const contract = contracts[contractName];
  
  if (!contract) {
    throw new Error(`Contract '${String(contractName)}' not found. Make sure it's registered in ContractProvider.`);
  }
  
  return contract;
} 