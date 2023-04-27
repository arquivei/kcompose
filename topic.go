package main

import (
	"strings"

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
		Action: Dispatcher(strings.Split("kcompose topic create input --replication-factor 1 --partitions 3", " ")),
	}
}
