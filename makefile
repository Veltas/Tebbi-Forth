# Copyright (c) 2023 Christopher Leonard
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
# KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

TARGET = tebbi-forth
OBJS = tebbi-forth.o
LINKER_SCRIPT = tebbi-forth.ld

ifeq ($(shell uname -s),Linux)
   ifneq ($(shell uname -p),i686)
      AS = i686-linux-gnu-as
      LD = i686-linux-gnu-ld
   endif
endif

$(TARGET): $(OBJS) $(LINKER_SCRIPT)
	$(LD) -T$(LINKER_SCRIPT) $(OBJS) -o$@

clean:
	-rm $(OBJS) $(TARGET)

%.o: %.s
	$(AS) $< -o$@
