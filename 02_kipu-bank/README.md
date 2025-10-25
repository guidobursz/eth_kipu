KipuBank

Sistema de bóveda personal para depósitos y retiros de ETH con límites de seguridad.


Descripción:


KipuBank es un smart contract desarrollado en Solidity que permite a los usuarios depositar y retirar ETH de manera segura a través de bóvedas personales. El contrato implementa restricciones de seguridad mediante límites globales de depósito y umbrales máximos de retiro por transacción.



Despliegue con Remix

Ir a Remix IDE
clonar el archivo KipuBank.sol
Compilar:
Compiler: 0.8.26

Desplegar:

Ir a "Deploy & Run Transactions"
Seleccionar KipuBank en el dropdown
Ingresar parámetros del constructor:

     _BANKCAP: 10000000000000000000      (10 ETH)
     _UMBRALRETIRO: 100000000000000000   (0.1 ETH)

Click en Deploy


Verificar en block explorer:

Copiar la dirección del contrato desplegado
Ir al block explorer de tu testnet
Verificar el código fuente



💻 Cómo Interactuar con el Contrato


Usando Remix


1. Depositar ETH
1. Ir al campo VALUE arriba
2. Ingresar cantidad: 1 [Ether]
3. Click en botón [depositar]
Resultado esperado:

✅ Transacción exitosa
✅ Evento KipuBank_DepositoRealizado emitido
✅ Balance actualizado

2. Retirar ETH

1. Campo VALUE en 0
2. En función retirar, ingresar:
   _monto: 100000000000000000  (0.1 ETH en wei)
3. Click en [retirar]
Resultado esperado:

✅ Transacción exitosa
✅ ETH enviado a tu wallet
✅ Balance reducido


3. Consultar Balance
consultarBalance("0xTU_DIRECCION")
Retorna:
balance_: 1000000000000000000  (1 ETH)


4. Consultar Estado del Banco
Click en [consultarEstadoBanco]
Retorna:
totalDepositado_: 5000000000000000000
contadorDepositos_: 42
contadorRetiros_: 15
bankCap_: 10000000000000000000
umbralRetiro_: 100000000000000000