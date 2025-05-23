import asyncdispatch
import httpclient
import parsecfg
import json, sequtils, strutils
import logging
import telebot

proc updateHandler(bot: TeleBot, u: Update): Future[bool] {.async.} =
  if u.callbackQuery != nil:
    let cb = u.callbackQuery
    let userID = u.callbackQuery.fromUser.id
    let msg = "Успешно получен контент\n" & cb.data
    var data: JsonNode
    let client = newAsyncHttpClient()
    let res = await client.get(cb.data)
    data = parseJson(await res.body)["results"]
    var buttons: seq[InlineKeyboardButton]
    var cnt = 0
    for item in data: # Если передавать одним сообщением, то не проходит по макс. числу символов
      cnt += 1
      buttons.add(newInlineKeyBoardButton(item["name"].getStr, callbackData=item["url"].getStr))
      discard await bot.sendMessage(
        userID,
        "Контент страницы $1/$2:\n```\n$3\n```" % [$cnt,$data.len,item.pretty(4)],
        parseMode = "Markdown",
      )
    discard await bot.sendMessage(
        userID,
        "Подробнее:",
        parseMode = "Markdown",
        replyMarkup = newInlineKeyboardMarkup(buttons.distribute(buttons.len div 2))
      )
    
    discard await bot.answerCallbackQuery(cb.id, msg, true)
  return true

proc startHandler(bot: TeleBot, command: Command): Future[bool] {.async.} =
  if not command.message.fromUser.isNil:
    let client = newAsyncHttpClient()
    let res = await client.get("https://swapi.py4e.com/api")
    let urls = parseJson(await res.body)
    var buttons: seq[InlineKeyboardButton]
    for k, v in urls:
      buttons.add(newInlineKeyBoardButton(k, callbackData=v.getStr))
    let name = command.message.fromUser.firstName
    discard await bot.sendMessage(
      command.message.chat.id,
      "Привет " & name & "!\nЯ SWAPI123-Bot.",
      parseMode = "Markdown",
      disableNotification = true,
      replyParameters = ReplyParameters(messageId: command.message.messageId),
      replyMarkup = newInlineKeyboardMarkup(buttons.distribute(buttons.len div 2))
    )
  return true

when isMainModule:
  let cfg = loadConfig(".env")
  let token = cfg.getSectionValue("", "TOKEN")
  let logger = newConsoleLogger(lvlInfo, fmtStr="[$date,$time][$levelname] ")
  logger.addHandler

  let bot = newTeleBot(token)
  logger.log(lvlInfo, "Bot started")
  bot.onCommand("start", startHandler)
  bot.onUpdate(updateHandler)
  bot.poll(timeout=100)
