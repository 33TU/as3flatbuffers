package internal

import (
	"encoding/binary"
	"strconv"
)

func identifierWord(o object) uint32 {
	if o.FileIdentifier == "" {
		return 0
	}
	return binary.LittleEndian.Uint32([]byte(o.FileIdentifier))
}

func generateIdentifier(w *IndentWriter, o object) {
	if o.FileIdentifier == "" {
		return
	}
	w.Line("public static const FILE_IDENTIFIER:String = %s;", strconv.Quote(o.FileIdentifier))
	w.BlankLine()
	w.Line("/** Check only the four-byte identifier; leaves the input cursor and endian unchanged. */")
	w.Line("public static function hasIdentifier(bytes:flash.utils.ByteArray, offset:uint = 0, sizePrefixed:Boolean = false):Boolean")
	w.Line("{")
	w.Indent()
	w.Line("const position:Number = Number(offset) + (sizePrefixed ? 8 : 4);")
	w.Line("return bytes != null && position + 4 <= bytes.length &&")
	w.Indent()
	w.Line("bytes[uint(position)] == %d && bytes[uint(position) + 1] == %d &&", o.FileIdentifier[0], o.FileIdentifier[1])
	w.Line("bytes[uint(position) + 2] == %d && bytes[uint(position) + 3] == %d;", o.FileIdentifier[2], o.FileIdentifier[3])
	w.Dedent()
	w.Dedent()
	w.Line("}")
	w.BlankLine()
}
