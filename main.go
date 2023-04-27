package main

import (
	"fmt"
	"os"
	"os/exec"

	"github.com/urfave/cli/v2"
)

var app = cli.NewApp()

func main() {
	app = &cli.App{
		Name:     "kcompose",
		Version:  "v1.0.0",
		Commands: getCommands(),
	}
	err := app.Run(os.Args)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		if exiterr, ok := err.(*exec.ExitError); ok {
			os.Exit(exiterr.ExitCode())
		}
		os.Exit(1)
	}
}

func getCommands() []*cli.Command {
	return []*cli.Command{
		getTopicCommand(),
	}
}
