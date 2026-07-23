package com.v2raystk.app

object LibboxBridge {
    init { System.loadLibrary("v2raystk") }
    external fun start(config: String, tunFd: Int): Boolean
    external fun stop()
    external fun traffic(): LongArray
}
