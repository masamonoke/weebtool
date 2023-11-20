def connect(db)
  return SQLite3::Database.open db
end

