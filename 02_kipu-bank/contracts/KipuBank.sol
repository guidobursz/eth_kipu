        // SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title Contrato KipuBank
 * @author guidobursz
 * @notice Sistema de bovedas personales para depositos y retiros de ETH
 * @dev Este contrato implementa limites de retiro y cap global de depositos
 * @custom:security Este es un contrato educativo - Módulo 2 EDP
 */
contract KipuBank {

    /*////////////////////////
        Variables de Estado
    ////////////////////////*/

    // Variables immutable
    /// @notice Umbral máximo de retiro por transaccion
        uint256 public immutable i_umbralRetiro;

    /// @notice Limite global de depositos del banco
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

   /// @notice Error emitido cuando el deposito excede el limite global del banco
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
    /**
        * @notice Modificador que valida que el monto sea mayor a cero
        * @dev Revierte si el valor enviado es cero
    */
    modifier montoMayorACero() {
        if (msg.value == 0) revert KipuBank_MontoDebeSerMayorACero();
        _;
    }

    /**
        * @notice Modificador que valida que el depósito no exceda el límite global del banco
        * @dev Revierte si el depósito haría que se supere el bankCap
    */
    modifier validarLimiteGlobal() {
        if (s_totalDepositado + msg.value > i_bankCap) {
            revert KipuBank_LimiteGlobalExcedido(
                s_totalDepositado,
                msg.value,
                i_bankCap
            );
        }
        _;
    }
    
    /*////////////////////////
            Funciones
    ////////////////////////*/
    
    /**
        * @notice Funcion para depositar eth en la boveda personal
        * @dev Antes de procesar el deposito valido el monto y el limite global
        * @dev incremento el balance del usuario, el total depositado y el contador de depositos
        * @dev Emite el evento KipuBank_DepositoRealizado si hay deposito exitoso
    */
    function depositar() external payable montoMayorACero validarLimiteGlobal {
        // actualizo el balance del usuario
        s_boveda[msg.sender] += msg.value;
        // actualizo el total depositado
        s_totalDepositado += msg.value;
        // actualizo el contador de depositos
        s_contadorDepositos++;
        
        // emito evento ok deposito
        emit KipuBank_DepositoRealizado(msg.sender, msg.value);
    }
    

    /**
        * @notice Permite a los usuarios retirar ETH de su bóveda personal
        * @param _monto Cantidad de ETH que el usuario desea retirar
        * @dev Valida que el monto sea mayor a cero, que el usuario tenga saldo suficiente
        * @dev y que no exceda el umbral de retiro por transaccion
        * @dev Emite el evento KipuBank_RetiroRealizado tras un retiro exitoso
    */
    function retirar(uint256 _monto) external {
        // Checks
        if (_monto == 0) revert KipuBank_MontoDebeSerMayorACero();
        
        if (s_boveda[msg.sender] < _monto) {
            revert KipuBank_SaldoInsuficiente(s_boveda[msg.sender], _monto);
        }
        
        if (_monto > i_umbralRetiro) {
            revert KipuBank_RetiroExcedeUmbral(_monto, i_umbralRetiro);
        }
        
        // Effects: actualizo el balance del usuario, el total depositado y el contador de retiros
        s_boveda[msg.sender] -= _monto;
        s_totalDepositado -= _monto;
        s_contadorRetiros++;
        
        // Interactions: Transferir ETH y emitir evento
        emit KipuBank_RetiroRealizado(msg.sender, _monto);
        _transferirEth(msg.sender, _monto);
    }
    
    /**
        * @notice Funcion privada para transferir ETH de forma segura
        * @param _destinatario Direccion que recibira el ETH
        * @param _monto Cantidad de ETH a transferir
    */
    function _transferirEth(address _destinatario, uint256 _monto) private {
        (bool ok, ) = _destinatario.call{value: _monto}("");
        if (!ok) revert KipuBank_TransferenciaFallida(_destinatario);
    }
    
    /**
        * @notice Funcion VIEW para consultar el balance de la boveda personal
        * @param _usuario Direccion del usuario que desea consultar el balance
        * @return balance_ Balance del usuario
    */
    function consultarBalance(address _usuario) external view returns (uint256 balance_) {
        balance_ = s_boveda[_usuario];
    }

    /**
        * @notice Consulta información general del banco
        * @return totalDepositado_ Total de ETH depositado en el banco
        * @return contadorDepositos_ Numero total de depositos realizados
        * @return contadorRetiros_ Numero total de retiros realizados
        * @return bankCap_ Limite maximo de depositos del banco
        * @return umbralRetiro_ Limite maximo por retiro
    */
    function consultarEstadoBanco() external view returns (
        uint256 totalDepositado_,
        uint256 contadorDepositos_,
        uint256 contadorRetiros_,
        uint256 bankCap_,
        uint256 umbralRetiro_
    ) {
        totalDepositado_ = s_totalDepositado;
        contadorDepositos_ = s_contadorDepositos;
        contadorRetiros_ = s_contadorRetiros;
        bankCap_ = i_bankCap;
        umbralRetiro_ = i_umbralRetiro;
    }
}