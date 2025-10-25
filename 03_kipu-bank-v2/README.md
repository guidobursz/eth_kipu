# KipuBankV2

Sistema avanzado de bóveda multi-token con integración de oráculos Chainlink y límites dinámicos en USD.

**Versión:** 2.0  
**Autor:** guidobursz
**Curso:** Ethereum Developer Pack - Módulo 3  

---

## Descripción

KipuBankV2 es una evolución del contrato original KipuBank, transformándolo de un sistema simple de bóveda ETH a una aplicación DeFi completa con soporte multi-token, integración de oráculos y contabilidad avanzada.

### Diferencias clave vs KipuBank v1:

| Característica | KipuBank v1 | KipuBankV2 |
|----------------|-------------|------------|
| Tokens soportados | Solo ETH | ETH + ERC20 (USDC) |
| Límites | En ETH (volátil) | En USD (estable) |
| Oráculos | No usa | Chainlink ETH/USD |
| Contabilidad | Simple mapping | Mapping anidado multi-token |
| Decimales | 18 (ETH) | Normalizado a 6 (USD) |
| Control de acceso | No tiene | Ownable (OpenZeppelin) |
| Protección reentrancy | Solo CEI | CEI + ReentrancyGuard |

---

## Mejoras Implementadas

### 1. Control de Acceso Basado en Roles

**Implementación:** Herencia de `Ownable` (OpenZeppelin)

---

### 2. Soporte Multi-Token

**Tokens soportados:**
- ETH nativo (representado como `address(0)`)
- USDC (ERC20)

**Arquitectura:**
```solidity
mapping(address user => mapping(address token => uint256 balanceUSD)) s_balances;
```

**Razón:** Permite a los usuarios diversificar sus activos dentro del mismo banco, manteniendo bóvedas independientes por token.

---

### 3. Integración con Chainlink Oracle

**Implementación:**
- Feed ETH/USD de Chainlink
- Conversión automática ETH → USD
- Validaciones de freshness (heartbeat)

**Razón:** Permite límites estables en USD independientes de la volatilidad de ETH.

---

### 6. Seguridad Reforzada

**Implementaciones:**

1. **ReentrancyGuard** (OpenZeppelin)
```solidity
function depositarETH() external payable nonReentrant { ... }
```

2. **SafeERC20** para transferencias
```solidity
i_usdc.safeTransferFrom(msg.sender, address(this), _amount);
```

3. **Patrón CEI** estricto

4. **Errores personalizados** (ahorro de gas)
```solidity
error KipuBankV2_SaldoInsuficiente(uint256 disponible, uint256 solicitado);
```

---

## Requisitos y Dependencias

### Dependencias de OpenZeppelin

```json
{
  "@openzeppelin/contracts": "^5.0.0"
}
```

**Contratos utilizados:**
- `Ownable.sol` - Control de acceso
- `ReentrancyGuard.sol` - Protección reentrancy
- `IERC20.sol` - Interfaz ERC20
- `SafeERC20.sol` - Transferencias seguras

### Dependencias de Chainlink

```json
{
  "@chainlink/contracts": "^1.0.0"
}
```

**Contratos utilizados:**
- `AggregatorV3Interface.sol` - Interfaz de Price Feeds

---

## Despliegue

Direccion contrato: 0x9AA5b6b0e01B9572433B5f3B0276988863b9be61

Link:  https://sepolia.etherscan.io/address/0x9AA5b6b0e01B9572433B5f3B0276988863b9be61  

