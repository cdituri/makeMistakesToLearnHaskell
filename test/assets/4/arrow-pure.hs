main = do
  input <- getContents
  splitByLine <- lines input
  putStr (unlines (reverse splitByLine))
