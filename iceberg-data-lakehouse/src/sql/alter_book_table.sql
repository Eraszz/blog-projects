ALTER TABLE book
ADD COLUMN publisher VARCHAR(150) NOT NULL DEFAULT 'Unknown Publisher';

INSERT INTO book (book_title, author, category, price, publisher) 
VALUES ('The Great Adventure', 'John Doe', 'Fiction', 19.99, 'Penguin Books');
