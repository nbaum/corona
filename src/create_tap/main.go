package main

import "os"
import "os/exec"
import "log"
import "fmt"

func run(args ...string) string {
	cmd := exec.Command(args[0], args[1:]...)
	bytes, err := cmd.CombinedOutput()
	if err != nil {
		log.Fatal("running ", args, " produced ", string(bytes))
	}
	return string(bytes)
}

func main() {
	if len(os.Args) < 0 {
		log.Fatal("usage: ??? NET NAME MAC")
	} else if len(os.Args) < 4 {
		log.Fatal("usage: ", os.Args[0], " NET NAME MAC")
	}
	net, name, mac := os.Args[1], os.Args[2], os.Args[3]
	run("ip", "link", "add", "link", net, "name", name, "type", "macvtap", "mode", "bridge")
	run("ip", "link", "set", name, "address", mac, "up")
	fmt.Printf("%s\n", run("ip", "link", "show", name))
}
