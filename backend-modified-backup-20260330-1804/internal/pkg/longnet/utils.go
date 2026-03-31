package longnet

import (
	"hash/fnv"
	"strconv"
)

func fnv32(key int64) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(strconv.FormatInt(key, 10)))
	return h.Sum32()
}

func fnv32Str(key string) uint32 {
	h := fnv.New32a()
	_, _ = h.Write([]byte(key))
	return h.Sum32()
}
