package main

import (
	"os"

	"github.com/urfave/cli/v2"
)

var app = cli.NewApp()

func main() {
	app := &cli.App{
		Name:     "kcompose",
		Version:  "v1.0.0",
		Commands: getCommands(),
	}
	app.Run(os.Args)
}

func getCommands() []*cli.Command {
	return []*cli.Command{
		getTopicCommand(),
	}
}
