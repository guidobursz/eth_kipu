// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*///////////////////////
        Imports
///////////////////////*/
//Para implementar propietario unico del contrato, pudiendo consultar quien es, poder transferir propiedad y renunciar.
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

//Para proteger de ataques de re-entrada.
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//Interfaz para acceder a las funciones estandar de un token.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Libreria para hacer mas segura la manipulacion de erc20
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Interfaz para interactuar con los Data Feeds de Chainlink (oraculos de precio)
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KipuBankV2
 * @author guidobursz
**/

contract KipuBankV2 is Ownable, ReentrancyGuard {
    
    /*///////////////////////
        Declaración de Tipos
    ///////////////////////*/
    using SafeERC20 for IERC20;


    /*///////////////////////
        Variables Constantes
    ///////////////////////*/
    
    /// @notice declaro eth nativo
    address public constant NATIVE_TOKEN = address(0);
    
    /// Defino decimales para ambos tokens, segun normalizacion
    uint256 constant USDC_DECIMALS = 6;
    uint256 constant ETH_DECIMALS = 18;
    
    /// @notice Heartbeat del oracle de Chainlink (1 hora)
    uint256 constant ORACLE_HEARTBEAT = 3600;
    
    /*///////////////////////
        Variables Immutable
    ///////////////////////*/
    
    /// @notice Límite global del banco en USD
    uint256 public immutable i_bankCapUSD;
    
    /// @notice Umbral máximo de retiro por transacción en USD
    uint256 public immutable i_umbralRetiroUSD;
    
    /// @notice Dirección del token USDC
    IERC20 public immutable i_usdc;
    


    /*///////////////////////
        Variables de Estado
    ///////////////////////*/
    
    /// @notice Oracle de Chainlink para obtener precio ETH/USD
    AggregatorV3Interface public s_ethUsdFeed;
    
    /// @notice Mapping anidado: usuario => token => balance en USD
    mapping(address user => mapping(address token => uint256 balanceUSD)) public s_balances;
    
    /// @notice Total depositado por token en USD
    mapping(address token => uint256 totalUSD) public s_totalDepositadoPorToken;
    
    /// @notice Total depositado global en USD (suma de todos los tokens)
    uint256 public s_totalDepositadoUSD;
    
    /// @notice Contador global de depósitos realizados
    uint256 public s_contadorDepositos;
    
    /// @notice Contador global de retiros realizados
    uint256 public s_contadorRetiros;
    


    /*///////////////////////
            Eventos
    ///////////////////////*/
    
    /// @notice Evento emitido cuando un usuario realiza un depósito exitoso
    /// @param usuario Dirección del usuario que depositó
    /// @param token Dirección del token depositado (address(0) para ETH)
    /// @param amount Cantidad depositada en unidades del token
    /// @param amountUSD Valor del depósito en USD
    event KipuBankV2_DepositoRealizado(
        address indexed usuario, 
        address indexed token, 
        uint256 amount, 
        uint256 amountUSD
    );

    /// @notice Evento emitido cuando un usuario realiza un retiro exitoso
    /// @param usuario Dirección del usuario que retiró
    /// @param token Dirección del token retirado (address(0) para ETH)
    /// @param amount Cantidad retirada en unidades del token
    /// @param amountUSD Valor del retiro en USD (6 decimales)
    event KipuBankV2_RetiroRealizado(
        address indexed usuario, 
        address indexed token, 
        uint256 amount, 
        uint256 amountUSD
    );


    /// @notice Evento emitido cuando el owner actualiza el feed de Chainlink
    /// @param newFeed Nueva dirección del feed ETH/USD
    event KipuBankV2_FeedActualizado(address indexed newFeed);

    
    /*///////////////////////
        Errores Personalizados
    ///////////////////////*/
    
    /// @notice Error emitido cuando el monto es cero
    error KipuBankV2_MontoDebeSerMayorACero();

    /// @notice Error emitido cuando el token no es soportado
    /// @param token Dirección del token no soportado
    error KipuBankV2_TokenNoSoportado(address token);


    /// @notice Error emitido cuando el depósito excede el límite global en USD
    /// @param totalActualUSD Total actualmente depositado en el banco
    /// @param intentoDepositoUSD Monto que se intenta depositar
    /// @param limiteUSD Límite máximo permitido (bankCap)
    error KipuBankV2_LimiteGlobalExcedidoUSD(
        uint256 totalActualUSD, 
        uint256 intentoDepositoUSD, 
        uint256 limiteUSD
    );

    /// @notice Error emitido cuando el usuario intenta retirar más de lo que tiene
    /// @param balanceDisponible Balance actual del usuario en USD
    /// @param montoSolicitado Monto que intenta retirar en USD
    error KipuBankV2_SaldoInsuficiente(uint256 balanceDisponible, uint256 montoSolicitado);

    /// @notice Error emitido cuando el retiro excede el umbral permitido por transacción
    /// @param montoSolicitadoUSD Monto que intenta retirar en USD
    /// @param umbralMaximoUSD Límite máximo por retiro en USD
    error KipuBankV2_RetiroExcedeUmbral(uint256 montoSolicitadoUSD, uint256 umbralMaximoUSD);

    /// @notice Error emitido cuando falla la transferencia de ETH
    /// @param destinatario Dirección a la que se intentó enviar
    error KipuBankV2_TransferenciaFallida(address destinatario);

    /// @notice Error emitido cuando el oráculo retorna un precio inválido
    error KipuBankV2_OracleCompromised();

    /// @notice Error emitido cuando el precio del oráculo está desactualizado
    /// @param tiempoTranscurrido Tiempo desde la última actualización
    /// @param heartbeat Tiempo máximo permitido
    error KipuBankV2_StalePrice(uint256 tiempoTranscurrido, uint256 heartbeat);


    
    /*///////////////////////
            Constructor
    ///////////////////////*/
    /**
     * @param _bankCapUSD Límite máximo total de depósitos en USD (6 decimales)
     * @param _umbralRetiroUSD Monto máximo por retiro en USD (6 decimales)
     * @param _ethUsdFeed Dirección del Chainlink Price Feed ETH/USD
     * @param _usdc Dirección del token USDC
     * @param _owner Dirección del propietario del contrato
     * @dev Los valores immutable se establecen aquí y no pueden cambiar después del deployment
     */
    constructor(
            uint256 _bankCapUSD,
            uint256 _umbralRetiroUSD,
            address _ethUsdFeed,
            address _usdc,
            address _owner
        )
        Ownable(_owner)
    {
        /*
            Valores deploy:
            i_bankCapUSD = 1000000000; //1000
            _umbralRetiroUSD = 100000000; //100
            _ethUsdFeed = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
            _usdc = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
            _owner = 0x652405FdecC7fCcA771752b83D5F6DB8be46a296
        */
        i_bankCapUSD = _bankCapUSD;
        i_umbralRetiroUSD = _umbralRetiroUSD;
        s_ethUsdFeed = AggregatorV3Interface(_ethUsdFeed);
        i_usdc = IERC20(_usdc);
    }

    
    /*///////////////////////
        Modificadores
    ///////////////////////*/
    
    /**
    * @notice Modificador que valida que el monto sea mayor a cero
    * @dev Revierte si el valor es cero
    */
    modifier montoMayorACero(uint256 _monto) {
        if (_monto == 0) revert KipuBankV2_MontoDebeSerMayorACero();
        _;
    }

    /**
    * @notice Modificador que valida que el token esté soportado
    * @param _token Dirección del token a validar
    * @dev Actualmente solo soporta ETH (address(0)) y USDC
    */
    modifier tokenSoportado(address _token) {
        if (_token != NATIVE_TOKEN && _token != address(i_usdc)) {
            revert KipuBankV2_TokenNoSoportado(_token);
        }
        _;
    }
    
    /*///////////////////////
        Funciones Externas
    ///////////////////////*/
    
    /**
    * @notice Permite depositar ETH nativo en la bóveda del usuario
    * @dev Convierte el ETH a USD usando Chainlink y valida el límite global
    * @dev El balance se almacena en USD
    */
    function depositarETH() external payable nonReentrant {
        // Checks: Validar que se envió ETH
        if (msg.value == 0) revert KipuBankV2_MontoDebeSerMayorACero();
        
        // Obtener valor eth a  USD
        uint256 valorUSD = _convertirEthAUsd(msg.value);
        
        // Valido limite global 
        if (s_totalDepositadoUSD + valorUSD > i_bankCapUSD) {
            revert KipuBankV2_LimiteGlobalExcedidoUSD(
                s_totalDepositadoUSD,
                valorUSD,
                i_bankCapUSD
            );
        }
        
        // Effects: Actualizar estado
        s_balances[msg.sender][NATIVE_TOKEN] += valorUSD;
        s_totalDepositadoPorToken[NATIVE_TOKEN] += valorUSD;
        s_totalDepositadoUSD += valorUSD;
        s_contadorDepositos++;
        
        // Interactions: Emitir evento
        emit KipuBankV2_DepositoRealizado(
            msg.sender,
            NATIVE_TOKEN,
            msg.value,    // Monto en ETH
            valorUSD      // Monto en USD
        );
    }


    /**
    * @notice Depositar directamente USDC
    * @dev Valida el límite global
    * @dev Incrementa el balance del usuario y el total depositado
    * @dev Emite el evento KipuBankV2_DepositoRealizado
    */
    function depositarUSDC(uint256 _amount) 
        external
        nonReentrant
        montoMayorACero(_amount)
    {        
        // Validar límite global
        if (s_totalDepositadoUSD + _amount > i_bankCapUSD) {
            revert KipuBankV2_LimiteGlobalExcedidoUSD(
                s_totalDepositadoUSD,
                _amount,
                i_bankCapUSD
            );
        }
        
        // Effects: Actualizar estado
        s_balances[msg.sender][address(i_usdc)] += _amount;
        s_totalDepositadoPorToken[address(i_usdc)] += _amount;
        s_totalDepositadoUSD += _amount;
        s_contadorDepositos++;
        
        //Interactions: Transferir tokens y emitir evento
        emit KipuBankV2_DepositoRealizado(
            msg.sender,
            address(i_usdc),
            _amount,
            _amount
        );
        
        IERC20(address(i_usdc)).safeTransferFrom(msg.sender, address(this), _amount);
    }


    /**
    * @notice Permite retirar ETH nativo de la bóveda del usuario
    * @param _amountETH Cantidad de ETH a retirar en wei
    * @dev Valida saldo suficiente y umbral de retiro en USD
    */
    function retirarETH(uint256 _amountETH) 
        external 
        nonReentrant 
        montoMayorACero(_amountETH) 
    {
        // Convertir el monto de ETH a USD
        uint256 valorUSD = _convertirEthAUsd(_amountETH);
        
        // Checks: Validar saldo suficiente
        if (s_balances[msg.sender][NATIVE_TOKEN] < valorUSD) {
            revert KipuBankV2_SaldoInsuficiente(
                s_balances[msg.sender][NATIVE_TOKEN],
                valorUSD
            );
        }
        
        // Checks: Validar umbral de retiro
        if (valorUSD > i_umbralRetiroUSD) {
            revert KipuBankV2_RetiroExcedeUmbral(valorUSD, i_umbralRetiroUSD);
        }
        
        // Effects: Actualizar estado
        s_balances[msg.sender][NATIVE_TOKEN] -= valorUSD;
        s_totalDepositadoPorToken[NATIVE_TOKEN] -= valorUSD;
        s_totalDepositadoUSD -= valorUSD;
        s_contadorRetiros++;
        
        // Interactions: Emitir evento y transferir ETH
        emit KipuBankV2_RetiroRealizado(
            msg.sender,
            NATIVE_TOKEN,
            _amountETH,
            valorUSD
        );
        
        _transferirEth(msg.sender, _amountETH);
    }


    /**
    * @notice Permite retirar USDC de la bóveda del usuario
    * @param _amount Cantidad de USDC a retirar
    * @dev Valida saldo suficiente y umbral de retiro en USD
    */
    function retirarUSDC(uint256 _amount) 
        external 
        nonReentrant 
        montoMayorACero(_amount)
    {
        // Checks: Validar umbral de retiro
        if (_amount > i_umbralRetiroUSD) {
            revert KipuBankV2_RetiroExcedeUmbral(_amount, i_umbralRetiroUSD);
        }

        // Checks: Validar saldo suficiente
        if (s_balances[msg.sender][address(i_usdc)] < _amount) {
            revert KipuBankV2_SaldoInsuficiente(
                s_balances[msg.sender][address(i_usdc)],
                _amount
            );
        }
        
        // Effects: Actualizar estado
        s_balances[msg.sender][address(i_usdc)] -= _amount;
        s_totalDepositadoPorToken[address(i_usdc)] -= _amount;
        s_totalDepositadoUSD -= _amount;
        s_contadorRetiros++;
        
        // Interactions: Emitir evento y transferir USDC
        emit KipuBankV2_RetiroRealizado(
            msg.sender,
            address(i_usdc),
            _amount,
            _amount
        );

        IERC20(address(i_usdc)).safeTransfer(msg.sender, _amount);
    }

    
    /*///////////////////////
        Funciones Públicas
    ///////////////////////*/
    
    /**
        * @notice Permite al dueno del contrato actualizar la dirección del Chainlink Price Feed
        * @param _newFeed Nueva dirección del feed ETH/USD
        * @dev Solo el propietario puede llamar esta función
    */
    function actualizarFeed(address _newFeed) external onlyOwner {
        s_ethUsdFeed = AggregatorV3Interface(_newFeed);
        emit KipuBankV2_FeedActualizado(_newFeed);
    }


    /*///////////////////////
        Funciones Internas
    ///////////////////////*/

    /**
    * @notice Convierte una cantidad de ETH a su valor equivalente en USD
    * @param _ethAmount Cantidad de ETH en wei 
    * @return valorUSD_ Valor en USD normalizado 
    * @dev Usa el precio de Chainlink y normaliza a 6 decimales
    */
    function _convertirEthAUsd(uint256 _ethAmount) internal view returns (uint256 valorUSD_) {
        uint256 precioEth = _obtenerPrecioEth();
        //1e20 para normalizar valor decimal
        valorUSD_ = (_ethAmount * precioEth) / 1e20;
    }


    /**
    * @notice Obtiene el precio actual de ETH en USD desde Chainlink
    * @return precioEth_ Precio de ETH en USD
    * @dev Valida que el precio sea válido y no esté desactualizado
    */
    function _obtenerPrecioEth() internal view returns (uint256 precioEth_) {
        (
            /* uint80 roundId */,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = s_ethUsdFeed.latestRoundData();
        
        // Validación 1: El precio debe ser mayor a 0
        if (answer <= 0) revert KipuBankV2_OracleCompromised();
        
        // Validación 2: El precio no debe estar desactualizado
        uint256 tiempoTranscurrido = block.timestamp - updatedAt;
        if (tiempoTranscurrido > ORACLE_HEARTBEAT) {
            revert KipuBankV2_StalePrice(tiempoTranscurrido, ORACLE_HEARTBEAT);
        }
        
        // Convertir int256 a uint256
        precioEth_ = uint256(answer);
    }
    
    /*///////////////////////
        Funciones Privadas
    ///////////////////////*/
        
    /**
    * @notice Función privada para transferir ETH de forma segura
    * @param _destinatario Dirección que recibirá el ETH
    * @param _monto Cantidad de ETH a transferir en wei
    * @dev Usa call para enviar ETH y revierte si la transferencia falla
    * @dev Esta función es privada y solo puede ser llamada internamente
    */
    function _transferirEth(address _destinatario, uint256 _monto) private {
        (bool success, ) = _destinatario.call{value: _monto}("");
        if (!success) revert KipuBankV2_TransferenciaFallida(_destinatario);
    }
    
    /*///////////////////////
        Funciones View/Pure
    ///////////////////////*/

    /**
    * @notice Consulta el balance de un usuario para un token específico
    * @param _usuario Dirección del usuario a consultar
    * @param _token Dirección del token (address(0) para ETH)
    * @return balance_ Balance del usuario en USD (6 decimales)
    */
    function consultarBalance(address _usuario, address _token) 
        external 
        view 
        returns (uint256 balance_) 
    {
        balance_ = s_balances[_usuario][_token];
    }

    /**
    * @notice Consulta el balance total de un usuario en USD (todos los tokens)
    * @param _usuario Dirección del usuario a consultar
    * @return balanceTotalUSD_ Balance total en USD (6 decimales)
    */
    function consultarBalanceTotalUSD(address _usuario) 
        external 
        view 
        returns (uint256 balanceTotalUSD_) 
    {
        // Sumar ETH + USDC
        balanceTotalUSD_ = s_balances[_usuario][NATIVE_TOKEN] + 
                        s_balances[_usuario][address(i_usdc)];
    }

    /**
    * @notice Consulta información general del estado del banco
    * @return totalDepositadoUSD_ Total depositado en el banco en USD
    * @return totalETH_ Total de ETH depositado en USD
    * @return totalUSDC_ Total de USDC depositado en USD
    * @return contadorDepositos_ Número total de depósitos realizados
    * @return contadorRetiros_ Número total de retiros realizados
    * @return bankCapUSD_ Límite máximo del banco en USD
    * @return umbralRetiroUSD_ Límite máximo por retiro en USD
    */
    function consultarEstadoBanco() 
        external 
        view 
        returns (
            uint256 totalDepositadoUSD_,
            uint256 totalETH_,
            uint256 totalUSDC_,
            uint256 contadorDepositos_,
            uint256 contadorRetiros_,
            uint256 bankCapUSD_,
            uint256 umbralRetiroUSD_
        ) 
    {
        totalDepositadoUSD_ = s_totalDepositadoUSD;
        totalETH_ = s_totalDepositadoPorToken[NATIVE_TOKEN];
        totalUSDC_ = s_totalDepositadoPorToken[address(i_usdc)];
        contadorDepositos_ = s_contadorDepositos;
        contadorRetiros_ = s_contadorRetiros;
        bankCapUSD_ = i_bankCapUSD;
        umbralRetiroUSD_ = i_umbralRetiroUSD;
    }

    //Funcion para ver le umbralMaximo de retiro
    function getUmbralRetiro() external view returns (uint256) {
        return i_umbralRetiroUSD;
    }

    /**
    * @notice Consulta el precio actual de ETH en USD desde Chainlink
    * @return precioETH_ Precio actual de ETH en USD (8 decimales)
    * @return ultimaActualizacion_ Timestamp de la última actualización
    */
    function consultarPrecioETH() 
        external 
        view 
        returns (uint256 precioETH_, uint256 ultimaActualizacion_) 
    {
        (
            /* uint80 roundId */,
            int256 answer,
            /* uint256 startedAt */,
            uint256 updatedAt,
            /* uint80 answeredInRound */
        ) = s_ethUsdFeed.latestRoundData();
        
        precioETH_ = uint256(answer);
        ultimaActualizacion_ = updatedAt;
    }
}