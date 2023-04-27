package main

import (
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
		return command.Run()
	}
}
