        // SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title Contrato KipuBank
 * @author guidobursz
 * @notice Sistema de bóveda personal para depósitos y retiros de ETH
 * @dev Este contrato implementa límites de retiro y cap global de depósitos
 * @custom:security Este es un contrato educativo - Módulo 2 EDP
 */
contract KipuBank {

    /*////////////////////////
        Variables de Estado
    ////////////////////////*/

    // Variables immutable
    /// @notice Umbral máximo de retiro por transacción (0.1 ETH)
        uint256 public immutable i_umbralRetiro;

    /// @notice Límite global de depósitos del banco
        uint256 public immutable i_bankCap;

    // Variables de almacenamiento (storage)
    /// @notice Total de ETH depositado en el banco
        uint256 public s_totalDepositado;

   /// @notice Contador global de depositos realizados
        uint256 public s_contadorDepositos;

   /// @notice Contador global de retiros realizados
        uint256 public s_contadorRetiros;


    // Mappings
        /// @notice Mapping que almacena el balance de cada usuario
        mapping(address usuario => uint256 balance) public s_boveda;

    /*////////////////////////
            Eventos
    ////////////////////////*/
    /*
        Le agrego el uso de indexed para poder filtrar en todas las transacciones realizadas en el contrato.
        En este caso, poder filtrar por usuario y tipo de evento.
     */
    
   /// @notice Evento emitido cuando un usuario realiza un depósito exitoso
   /// @param usuario Direccion del usuario que deposito
   /// @param monto Cantidad de ETH depositada
        event KipuBank_DepositoRealizado(address indexed usuario, uint256 monto);


   /// @notice Evento emitido cuando un usuario realiza un retiro exitoso
   /// @param usuario Direccion del usuario que retiro
   /// @param monto Cantidad de ETH retirada
        event KipuBank_RetiroRealizado(address indexed usuario, uint256 monto);

    /*////////////////////////
        Errores Personalizados
    ////////////////////////*/

   /// @notice Error emitido cuando el deposito excede el límite global del banco
   /// @param depositoActual Total actualmente depositado en el banco
   /// @param intentoDeposito Monto que se intenta depositar
   /// @param limiteMaximo Limite maximo permitido (bankCap)
        error KipuBank_LimiteGlobalExcedido(uint256 depositoActual, uint256 intentoDeposito, uint256 limiteMaximo);

   /// @notice Error emitido cuando el usuario intenta retirar mas de lo que tiene
   /// @param balanceDisponible Balance actual del usuario
   /// @param montoSolicitado Monto que intenta retirar
        error KipuBank_SaldoInsuficiente(uint256 balanceDisponible, uint256 montoSolicitado);

   /// @notice Error emitido cuando el retiro excede el umbral permitido por transaccion
   /// @param montoSolicitado Monto que intenta retirar
   /// @param umbralMaximo Limite maximo por retiro
        error KipuBank_RetiroExcedeUmbral(uint256 montoSolicitado, uint256 umbralMaximo);

   /// @notice Error emitido cuando el monto del deposito es cero
        error KipuBank_MontoDebeSerMayorACero();

   /// @notice Error emitido cuando falla la transferencia de ETH
   /// @param destinatario Direccion a la que se intento enviar
        error KipuBank_TransferenciaFallida(address destinatario);

    /*////////////////////////
            Constructor
    ////////////////////////*/
   /**
    * @notice Inicializa el contrato KipuBank con los parámetros de configuración
     * @param _bankCap Limite maximo total de depositos permitidos en el banco
     * @param _umbralRetiro Monto maximo que se puede retirar por transaccion
     * @dev Los valores se establecen como immutable y no pueden cambiar despues del deployment
    */
        constructor(uint256 _bankCap, uint256 _umbralRetiro) {
                i_bankCap = _bankCap;
                i_umbralRetiro = _umbralRetiro;
        }
    
    /*////////////////////////
            Modificadores
    ////////////////////////*/
    
    
    /*////////////////////////
            Funciones
    ////////////////////////*/
    
    // Función external payable (depositar)
    
    // Función external (retirar)
    
    // Función external view (consultar)
    
    // Función private (lógica interna)
    
}