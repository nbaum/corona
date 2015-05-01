package main

import "os"
import "os/exec"
import "log"
import "fmt"

func run(args ...string) (string, error) {
	cmd := exec.Command(args[0], args[1:]...)
	bytes, err := cmd.CombinedOutput()
	return string(bytes), err
}

func run2(args ...string) string {
	str, err := run(args...)
	if err != nil {
		log.Fatal("running ", args, " produced ", str)
	}
	return str
}

func main() {
	if len(os.Args) < 0 {
		log.Fatal("usage: ??? NET NAME MAC")
	} else if len(os.Args) < 4 {
		log.Fatal("usage: ", os.Args[0], " NET NAME MAC")
	}
	net, name, mac := os.Args[1], os.Args[2], os.Args[3]
	run("ip", "link", "add", "link", net, "name", name, "type", "macvtap", "mode", "bridge")
	run2("ip", "link", "set", name, "address", mac, "up")
	fmt.Printf("%s\n", run2("ip", "link", "show", name))
}
