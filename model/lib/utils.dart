// This file is derived from https://github.com/flutter/engine/blob/master/sky/engine/core/dart/hash_codes.dart

// Copyright 2014 The Chromium Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class _HashEnd { const _HashEnd(); }
const _HashEnd _hashEnd = const _HashEnd();

int hashValues(
  Object arg01,            Object arg02,          [ Object arg03 = _hashEnd,
  Object arg04 = _hashEnd, Object arg05 = _hashEnd, Object arg06 = _hashEnd,
  Object arg07 = _hashEnd, Object arg08 = _hashEnd, Object arg09 = _hashEnd,
  Object arg10 = _hashEnd, Object arg11 = _hashEnd, Object arg12 = _hashEnd,
  Object arg13 = _hashEnd, Object arg14 = _hashEnd, Object arg15 = _hashEnd,
  Object arg16 = _hashEnd, Object arg17 = _hashEnd, Object arg18 = _hashEnd,
  Object arg19 = _hashEnd, Object arg20 = _hashEnd ]) {
  int result = 373;
  assert(arg01 is! Iterable);
  result = 37 * result + arg01.hashCode;
  assert(arg02 is! Iterable);
  result = 37 * result + arg02.hashCode;
  if (arg03 != _hashEnd) {
    assert(arg03 is! Iterable);
    result = 37 * result + arg03.hashCode;
    if (arg04 != _hashEnd) {
      assert(arg04 is! Iterable);
      result = 37 * result + arg04.hashCode;
      if (arg05 != _hashEnd) {
        assert(arg05 is! Iterable);
        result = 37 * result + arg05.hashCode;
        if (arg06 != _hashEnd) {
          assert(arg06 is! Iterable);
          result = 37 * result + arg06.hashCode;
          if (arg07 != _hashEnd) {
            assert(arg07 is! Iterable);
            result = 37 * result + arg07.hashCode;
            if (arg08 != _hashEnd) {
              assert(arg08 is! Iterable);
              result = 37 * result + arg08.hashCode;
              if (arg09 != _hashEnd) {
                assert(arg09 is! Iterable);
                result = 37 * result + arg09.hashCode;
                if (arg10 != _hashEnd) {
                  assert(arg10 is! Iterable);
                  result = 37 * result + arg10.hashCode;
                  if (arg11 != _hashEnd) {
                    assert(arg11 is! Iterable);
                    result = 37 * result + arg11.hashCode;
                    if (arg12 != _hashEnd) {
                      assert(arg12 is! Iterable);
                      result = 37 * result + arg12.hashCode;
                      if (arg13 != _hashEnd) {
                        assert(arg13 is! Iterable);
                        result = 37 * result + arg13.hashCode;
                        if (arg14 != _hashEnd) {
                          assert(arg14 is! Iterable);
                          result = 37 * result + arg14.hashCode;
                          if (arg15 != _hashEnd) {
                            assert(arg15 is! Iterable);
                            result = 37 * result + arg15.hashCode;
                            if (arg16 != _hashEnd) {
                              assert(arg16 is! Iterable);
                              result = 37 * result + arg16.hashCode;
                              if (arg17 != _hashEnd) {
                                assert(arg17 is! Iterable);
                                result = 37 * result + arg17.hashCode;
                                if (arg18 != _hashEnd) {
                                  assert(arg18 is! Iterable);
                                  result = 37 * result + arg18.hashCode;
                                  if (arg19 != _hashEnd) {
                                    assert(arg19 is! Iterable);
                                    result = 37 * result + arg19.hashCode;
                                    if (arg20 != _hashEnd) {
                                      assert(arg20 is! Iterable);
                                      result = 37 * result + arg20.hashCode;
                                      // I can see my house from here!
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  return result;
}
