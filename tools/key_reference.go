//go:build ignore

// Run by key_interop.py against a temporary flatc-generated Go package.
package main

import (
	"fmt"
	flatbuffers "github.com/google/flatbuffers/go"
	"keyreference/fixture"
	"os"
)

func main() {
	original, err := os.ReadFile(os.Args[2])
	if err != nil {
		panic(err)
	}
	source := fixture.GetRootAsDirectory(original, 0)
	if os.Args[1] == "create" {
		builder := flatbuffers.NewBuilder(16)
		// Write value first and force its zero slot. Go's vtable dedup compares
		// field offsets but omits object size: keeping wide-key layouts distinct
		// avoids aliasing a 64-bit field with a shorter scalar table here.
		var offsetsSigned []flatbuffers.UOffsetT
		var itemSigned fixture.Signed
		for i := source.SignedLength() - 1; i >= 0; i-- {
			source.Signed(&itemSigned, i)
			key := itemSigned.Id()
			fixture.SignedStart(builder)
			builder.PrependUint32(itemSigned.Value())
			builder.Slot(1)
			fixture.SignedAddId(builder, key)
			offsetsSigned = append(offsetsSigned, fixture.SignedEnd(builder))
		}
		vectorSigned := builder.CreateVectorOfSortedTables(offsetsSigned, fixture.SignedKeyCompare)
		var offsetsUnsigned []flatbuffers.UOffsetT
		var itemUnsigned fixture.Unsigned
		for i := source.UnsignedLength() - 1; i >= 0; i-- {
			source.Unsigned(&itemUnsigned, i)
			key := itemUnsigned.Id()
			fixture.UnsignedStart(builder)
			builder.PrependUint32(itemUnsigned.Value())
			builder.Slot(1)
			fixture.UnsignedAddId(builder, key)
			offsetsUnsigned = append(offsetsUnsigned, fixture.UnsignedEnd(builder))
		}
		vectorUnsigned := builder.CreateVectorOfSortedTables(offsetsUnsigned, fixture.UnsignedKeyCompare)
		var offsetsTexts []flatbuffers.UOffsetT
		var itemTexts fixture.TextKey
		for i := source.TextsLength() - 1; i >= 0; i-- {
			source.Texts(&itemTexts, i)
			key := itemTexts.Name()
			encoded := builder.CreateByteString(key)
			fixture.TextKeyStart(builder)
			builder.PrependUint32(itemTexts.Value())
			builder.Slot(1)
			fixture.TextKeyAddName(builder, encoded)
			offsetsTexts = append(offsetsTexts, fixture.TextKeyEnd(builder))
		}
		vectorTexts := builder.CreateVectorOfSortedTables(offsetsTexts, fixture.TextKeyKeyCompare)
		var offsetsLongs []flatbuffers.UOffsetT
		var itemLongs fixture.LongKey
		for i := source.LongsLength() - 1; i >= 0; i-- {
			source.Longs(&itemLongs, i)
			key := itemLongs.Id()
			fixture.LongKeyStart(builder)
			builder.PrependUint32(itemLongs.Value())
			builder.Slot(1)
			fixture.LongKeyAddId(builder, key)
			offsetsLongs = append(offsetsLongs, fixture.LongKeyEnd(builder))
		}
		vectorLongs := builder.CreateVectorOfSortedTables(offsetsLongs, fixture.LongKeyKeyCompare)
		var offsetsUlongs []flatbuffers.UOffsetT
		var itemUlongs fixture.ULongKey
		for i := source.UlongsLength() - 1; i >= 0; i-- {
			source.Ulongs(&itemUlongs, i)
			key := itemUlongs.Id()
			fixture.ULongKeyStart(builder)
			builder.PrependUint32(itemUlongs.Value())
			builder.Slot(1)
			fixture.ULongKeyAddId(builder, key)
			offsetsUlongs = append(offsetsUlongs, fixture.ULongKeyEnd(builder))
		}
		vectorUlongs := builder.CreateVectorOfSortedTables(offsetsUlongs, fixture.ULongKeyKeyCompare)
		fixture.DirectoryStart(builder)
		fixture.DirectoryAddSigned(builder, vectorSigned)
		fixture.DirectoryAddUnsigned(builder, vectorUnsigned)
		fixture.DirectoryAddTexts(builder, vectorTexts)
		fixture.DirectoryAddLongs(builder, vectorLongs)
		fixture.DirectoryAddUlongs(builder, vectorUlongs)
		builder.Finish(fixture.DirectoryEnd(builder))
		if err := os.WriteFile(os.Args[3], builder.FinishedBytes(), 0600); err != nil {
			panic(err)
		}
		return
	}
	packed, err := os.ReadFile(os.Args[3])
	if err != nil {
		panic(err)
	}
	result := fixture.GetRootAsDirectory(packed, 0)
	var expectedSigned, actualSigned fixture.Signed
	if result.SignedLength() != source.SignedLength() {
		panic("Signed length mismatch")
	}
	for i := 0; i < source.SignedLength(); i++ {
		source.Signed(&expectedSigned, i)
		key := expectedSigned.Id()
		if !result.SignedByKey(&actualSigned, key) || actualSigned.Value() != expectedSigned.Value() {
			panic(fmt.Sprintf("Signed lookup failed at %d", i))
		}
	}
	var expectedUnsigned, actualUnsigned fixture.Unsigned
	if result.UnsignedLength() != source.UnsignedLength() {
		panic("Unsigned length mismatch")
	}
	for i := 0; i < source.UnsignedLength(); i++ {
		source.Unsigned(&expectedUnsigned, i)
		key := expectedUnsigned.Id()
		if !result.UnsignedByKey(&actualUnsigned, key) || actualUnsigned.Value() != expectedUnsigned.Value() {
			panic(fmt.Sprintf("Unsigned lookup failed at %d", i))
		}
	}
	var expectedTexts, actualTexts fixture.TextKey
	if result.TextsLength() != source.TextsLength() {
		panic("Texts length mismatch")
	}
	for i := 0; i < source.TextsLength(); i++ {
		source.Texts(&expectedTexts, i)
		key := expectedTexts.Name()
		if !result.TextsByKey(&actualTexts, string(key)) || actualTexts.Value() != expectedTexts.Value() {
			panic(fmt.Sprintf("Texts lookup failed at %d", i))
		}
	}
	var expectedLongs, actualLongs fixture.LongKey
	if result.LongsLength() != source.LongsLength() {
		panic("Longs length mismatch")
	}
	for i := 0; i < source.LongsLength(); i++ {
		source.Longs(&expectedLongs, i)
		key := expectedLongs.Id()
		if !result.LongsByKey(&actualLongs, key) || actualLongs.Value() != expectedLongs.Value() {
			panic(fmt.Sprintf("Longs lookup failed at %d", i))
		}
	}
	var expectedUlongs, actualUlongs fixture.ULongKey
	if result.UlongsLength() != source.UlongsLength() {
		panic("Ulongs length mismatch")
	}
	for i := 0; i < source.UlongsLength(); i++ {
		source.Ulongs(&expectedUlongs, i)
		key := expectedUlongs.Id()
		if !result.UlongsByKey(&actualUlongs, key) || actualUlongs.Value() != expectedUlongs.Value() {
			panic(fmt.Sprintf("Ulongs lookup failed at %d", i))
		}
	}
	fmt.Println("Go ByKey verified signed, unsigned, UTF-8 and exact 64-bit AS3 keys")
}
