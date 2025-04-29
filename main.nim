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

    # Реализуйте обработку контента с эндпоинта cb.data
    # можно обработать только первую страницу. Этого достаточно
    var data: JsonNode
    # var buttons: seq[InlineKeyboardButton] - по желанию
    # можно сделать новые кнопки для текущего сообщения,
    # в качестве названия, например, значение поля ["results"]["name"]
    # в качестве callbackData - ["results"]["url"]
    # Всё зависит от JSON.

    discard await bot.sendMessage(
      userID,
      "Контент страницы:\n```\n$1\n```" % data.pretty(4),
      parseMode = "Markdown",
      # replyMarkup = newInlineKeyboardMarkup(buttons.distribute(buttons.len div 2))
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
      "Привет " & name & "!\nЯ SWAPI-Bot.",
      parseMode = "Markdown",
      disableNotification = true,
      replyParameters = ReplyParameters(messageId: command.message.messageId),
      replyMarkup = newInlineKeyboardMarkup(buttons.distribute(buttons.len div 2))
    )
  return true

when isMainModule:
  let cfg = loadConfig(".env")  # не забудьте создать
  let token = cfg.getSectionValue("", "TOKEN")
  let logger = newConsoleLogger(lvlInfo, fmtStr="[$date,$time][$levelname] ")
  logger.addHandler

  let bot = newTeleBot(token)
  logger.log(lvlInfo, "Bot started")
  bot.onCommand("start", startHandler)
  bot.onUpdate(updateHandler)
  bot.poll(timeout=100)
