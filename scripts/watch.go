package main

import (
    "fmt"
    "log"
    "context"
    "math/big"
    "strings"

    "github.com/ethereum/go-ethereum"
    "github.com/ethereum/go-ethereum/accounts/abi"
    "github.com/ethereum/go-ethereum/common"
    "github.com/ethereum/go-ethereum/crypto"
    "github.com/ethereum/go-ethereum/ethclient"
    "github.com/ethereum/go-ethereum/core/types"

    token "../go"
)

func main() {
    client, err := ethclient.Dial("wss://rinkeby.infura.io/ws")
    if err != nil {
        log.Fatal(err)
    }

    const ContribTokenAddress string = "0x682391Bd5839a1b49079C555658dB77028b7F1e1"
    const CurrencyTokenAddress string = "0x605c885A40600c9647587Fe8B1EdFB578F7d6A9b"

    fmt.Println("we have a connection")

    contribAddress := common.HexToAddress(ContribTokenAddress)
    currencyAddress := common.HexToAddress(ContribTokenAddress)
    // Get contract instances to call methods on them
    contribInstance, _ := token.NewToken(contribAddress, client)
    currencyInstance, _ := token.NewToken(currencyAddress, client)
    _ = contribInstance
    _ = currencyInstance

    tokenAbi, _ := abi.JSON(strings.NewReader(string(token.TokenABI)))

    transferEventSigHash := crypto.Keccak256Hash([]byte("Transfer(address,address,uint256)"))

    query := ethereum.FilterQuery{
        FromBlock: big.NewInt(5356339),
        Addresses: []common.Address{contribAddress,currencyAddress},
    }

    // We can process any events since `FromBlock`
    past, _ := client.FilterLogs(context.Background(), query)

    for _, vLog := range past {

      // The transaction hash can work as a unique transaction identifier (for example, checking whether a transaction been processed/synced)
      fmt.Println("\nTxHash:", vLog.TxHash.Hex())

      switch vLog.Topics[0] {
    	case transferEventSigHash:
          switch vLog.Address {
          case contribAddress:
              fmt.Println("Contrib Transfer")
          case currencyAddress:
    		      fmt.Println("Currency Transfer")
          default:
              fmt.Println("unrecognised token Transfer event")
          }

          var event token.TokenTransfer
          tokenAbi.Unpack(&event, "Transfer", vLog.Data)

          var senderAddress common.Address = common.HexToAddress(vLog.Topics[1].Hex())
          var receiverAddress common.Address = common.HexToAddress(vLog.Topics[2].Hex())
          fmt.Println("\tSender:", senderAddress.Hex())
          fmt.Println("\tReceiver:", receiverAddress.Hex())
          fmt.Println("\tAmount:", event.Amount)

          // sender & receiver balances will have changed. Call the BalanceOf method on the contract instance
          // to get the updated balance for that account
          // when the sender/from address is 0x0000000000000000000000000000000000000000 tokens were minted
          // when the receiver/to address is 0x0000000000000000000000000000000000000000 tokens were burned
          switch vLog.Address {
          case contribAddress:
              senderBalance, _ := contribInstance.BalanceOf(nil, senderAddress)
              receiverBalance, _ := contribInstance.BalanceOf(nil, receiverAddress)
              supply, _ := contribInstance.TotalSupply(nil)
              fmt.Println("\tSender new balance:", senderBalance)
              fmt.Println("\tReceiver new balance:", receiverBalance)
              fmt.Println("\tNew total supply:", supply)
          case currencyAddress:
              senderBalance, _ := currencyInstance.BalanceOf(nil, senderAddress)
              receiverBalance, _ := currencyInstance.BalanceOf(nil, receiverAddress)
              supply, _ := currencyInstance.TotalSupply(nil)
              fmt.Println("\tSender new balance:", senderBalance)
              fmt.Println("\tReceiver new balance:", receiverBalance)
              fmt.Println("\tNew total supply:", supply)
          }

    	default:
		      fmt.Println("not a monitored event")
    	}
    }

    // As well as process past events we can create an event subscription and monitor for ongoing events
    logs := make(chan types.Log)

    sub, err := client.SubscribeFilterLogs(context.Background(), query, logs)
    if err != nil {
        log.Fatal(err)
    }

    for {
        select {
        case err := <-sub.Err():
            log.Fatal(err)
        case vLog := <-logs:
          switch vLog.Topics[0] {
          case transferEventSigHash:
              switch vLog.Address {
              case contribAddress:
                  fmt.Println("Contrib Transfer")
              case currencyAddress:
                  fmt.Println("Currency Transfer")
              default:
                  fmt.Println("unrecognised token Transfer event")
              }
          default:
              fmt.Println("not a monitored event")
          }
        }
    }
}
