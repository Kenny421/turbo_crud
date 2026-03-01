TurboCrud.configure do |c|
  c.default_container = :modal   # or :drawer
  c.default_insert    = :prepend # or :append

  # Row partial auto-detect is default (:auto)
  # If your app uses a custom partial path, set it:
  # c.row_partial = "posts/post"
end