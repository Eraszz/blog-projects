-- Insert a new random book record
INSERT INTO book (book_title, author, category, price)
VALUES 
('The Great Adventure', 'Alice Walker', 'Adventure', 19.99);

-- Modify the author of an existing book (book_id = 2)
UPDATE book 
SET author = 'George Orwell' 
WHERE book_id = 2;