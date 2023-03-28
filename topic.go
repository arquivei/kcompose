package main

import (
	"github.com/urfave/cli/v2"
)

func getTopicCommand() *cli.Command {
	return &cli.Command{
		Name:        "topic",
		Usage:       "topic",
		Subcommands: getTopicSubcomands(),
	}
}

func getTopicSubcomands() []*cli.Command {
	return []*cli.Command{
		topicListSubcommand(),
	}
}

func topicListSubcommand() *cli.Command {
	return &cli.Command{
		Name:   "list",
		Usage:  "list",
		Action: Dispatcher([]string{"echo", "topic list executed"}),
		// Action: Dispatcher([]string{"não deu certo"}),
	}
}
