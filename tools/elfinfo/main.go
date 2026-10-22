package main

import (
	"debug/elf"
	"fmt"
	"os"
)

func main() {
	for _, p := range os.Args[1:] {
		f, err := elf.Open(p)
		if err != nil {
			fmt.Printf("%s: %v\n", p, err)
			continue
		}
		fmt.Printf("%s: class=%v machine=%v osabi=%v type=%v entry=%#x\n", p, f.Class, f.Machine, f.OSABI, f.Type, f.Entry)
		for _, s := range f.Sections {
			if s.Name == ".ARM.attributes" {
				b, _ := s.Data()
				fmt.Printf("  .ARM.attributes %d bytes: %x\n", len(b), b)
			}
		}
		fmt.Printf("  interp=%v\n", func() string {
			for _, s := range f.Sections {
				if s.Name == ".interp" {
					b, _ := s.Data()
					return string(b)
				}
			}
			return "(static)"
		}())
		f.Close()
	}
}
