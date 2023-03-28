package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/urfave/cli/v2"
)

func Dispatcher(commands []string) cli.ActionFunc {
	return func(c *cli.Context) error {
		command := exec.Command(commands[0], commands[0:]...)
		command.Stdout = os.Stdout
		command.Stdin = os.Stdin
		command.Stderr = os.Stderr
		if err := command.Run(); err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}
		os.Exit(0)
		return nil
	}
}
