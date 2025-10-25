// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (última actualización v5.1.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.20;

/**
 * @dev Interfaz del estándar ERC-20 según lo definido en el ERC.
 */
interface IERC20 {
    /**
     * @dev Emitido cuando `value` tokens son movidos de una cuenta (`from`) a
     * otra (`to`).
     *
     * Nota que `value` puede ser cero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitido cuando el permiso de un `spender` para un `owner` es establecido
     * mediante una llamada a {approve}. `value` es el nuevo permiso.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Devuelve el valor total de tokens en existencia.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Devuelve el valor de tokens que posee la `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Mueve una cantidad de tokens `value` desde la cuenta del llamador a `to`.
     *
     * Devuelve un valor booleano indicando si la operación fue exitosa.
     *
     * Emite un evento {Transfer}.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Devuelve el número restante de tokens que `spender` podrá
     * gastar en nombre de `owner` mediante {transferFrom}. Por defecto es cero.
     *
     * Este valor cambia cuando se llaman {approve} o {transferFrom}.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Establece una cantidad de tokens `value` como permiso de `spender` sobre los
     * tokens del llamador.
     *
     * Devuelve un valor booleano indicando si la operación fue exitosa.
     *
     * IMPORTANTE: Tenga cuidado que cambiar un permiso con este método conlleva el riesgo
     * de que alguien pueda usar tanto el permiso antiguo como el nuevo debido a un orden
     * desafortunado de transacciones. Una posible solución para mitigar esta condición de carrera
     * es primero reducir el permiso del gastador a 0 y luego establecer el valor deseado:
     * <https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729>
     *
     * Emite un evento {Approval}.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Mueve una cantidad de tokens `value` desde `from` hacia `to` usando el
     * mecanismo de permisos. `value` se deduce del permiso del llamador.
     *
     * Devuelve un valor booleano indicando si la operación fue exitosa.
     *
     * Emite un evento {Transfer}.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
