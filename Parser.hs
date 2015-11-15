module Parser where

import Text.Parsec hiding (label)
import Text.Parsec.String (Parser)

import Data.ByteString.Char8 (pack)
import Control.Monad (void)

import qualified Text.Parsec.Expr as Ex
import qualified Text.Parsec.Token as Token

import Lexer
import Syntax

taggedImage :: Parser BaseImage
taggedImage = do
  name <- many (noneOf ":")
  reservedOp ":"
  tag <- many (noneOf "\n")
  return $ TaggedImage name tag

digestedImage :: Parser BaseImage
digestedImage = do
  name <- many (noneOf "@")
  reservedOp "@"
  digest <- many (noneOf "\n")
  return $ DigestedImage name (pack digest)

untaggedImage :: Parser BaseImage
untaggedImage = do
  name <- many (noneOf "\n")
  return $ LatestImage name

baseImage :: Parser BaseImage
baseImage = try taggedImage
    <|> try digestedImage
    <|> try untaggedImage

from :: Parser Instruction
from = do
  reserved "FROM"
  image <- baseImage
  eol
  return $ From image

env :: Parser Instruction
env = do
  reserved "ENV"
  key <- many (noneOf [' ','='])
  _ <- oneOf[' ','=']
  value <- many (noneOf "\n")
  eol
  return $ Env key value

cmd :: Parser Instruction
cmd = do
  reserved "CMD"
  args <- many (noneOf "\n")
  eol
  return $ Cmd args

copy :: Parser Instruction
copy = do
  reserved "COPY"
  args <- many (noneOf "\n")
  eol
  return $ Copy args

stopsignal :: Parser Instruction
stopsignal = do
  reserved "STOPSIGNAL"
  args <- many (noneOf "\n")
  eol
  return $ Stopsignal args

label :: Parser Instruction
label = do
  reserved "LABEL"
  args <- many (noneOf "\n")
  eol
  return $ Label args

user :: Parser Instruction
user = do
  reserved "USER"
  args <- many (noneOf "\n")
  eol
  return $ User args

add :: Parser Instruction
add = do
  reserved "ADD"
  args <- many (noneOf "\n")
  eol
  return $ Add args

expose :: Parser Instruction
expose = do
  reserved "EXPOSE"
  port <- natural
  eol
  return $ Expose port

run :: Parser Instruction
run = do
  reserved "RUN"
  cmd <- many (noneOf "\n")
  eol
  return $ Run cmd

workdir :: Parser Instruction
workdir = do
  reserved "WORKDIR"
  directory <- many (noneOf "\n")
  eol
  return $ Workdir directory

volume :: Parser Instruction
volume = do
  reserved "VOLUME"
  directory <- many (noneOf "\n")
  eol
  return $ Volume directory

maintainer :: Parser Instruction
maintainer = do
  reserved "MAINTAINER"
  name <- many (noneOf "\n")
  eol
  return $ Maintainer name

entrypoint:: Parser Instruction
entrypoint = do
  reserved "ENTRYPOINT"
  name <- many (noneOf "\n")
  eol
  return $ Entrypoint name

instruction :: Parser Instruction
instruction = try from
    <|> try copy
    <|> try run
    <|> try workdir
    <|> try entrypoint
    <|> try volume
    <|> try expose
    <|> try env
    <|> try user
    <|> try label
    <|> try stopsignal
    <|> try cmd
    <|> try maintainer

contents :: Parser a -> Parser a
contents p = do
    Token.whiteSpace lexer
    r <- p
    eof
    return r

eol :: Parser ()
eol = void (char '\n') <|> eof

dockerfile :: Parser Dockerfile
dockerfile = many $ do
    i <- instruction
    return i

parseString :: String -> Either ParseError Dockerfile
parseString input = parse (contents dockerfile) "<string>" input

parseFile :: String -> IO (Either ParseError Dockerfile)
parseFile file = do
    program <- readFile file
    return (parse (contents dockerfile) "<file>" program)
