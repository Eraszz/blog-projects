-- Insert sales records without specifying sale_id (auto-incremented)
INSERT INTO sales (customer_id, book_id, quantity, unit_price, total_price, sale_date)
VALUES
    (1, 1, 2, 20.99, 41.98, '2024-08-11'),  -- Christiane Paffrath buys 2 copies of 'The Last Summer in Vienna'
    (2, 3, 1, 25.15, 25.15, '2024-11-06'),  -- Arnold Reuter buys 1 copy of 'The Phantom of Blackwood Manor'
    (3, 4, 3, 25.18, 75.54, '2024-09-01'),  -- Louise Beckmann buys 3 copies of 'Chasing Shadows'
    (4, 5, 1, 22.61, 22.61, '2024-08-15'),  -- Imke Zimmer buys 1 copy of 'A Love to Remember'
    (5, 2, 2, 10.47, 20.94, '2024-10-22'),  -- Anna-Luise Gerlach buys 2 copies of 'A History of the Modern World'
    (1, 4, 4, 25.18, 100.72, '2024-10-22'),  -- Christiane Paffrath buys 4 copies of 'Chasing Shadows'
    (2, 5, 3, 22.61, 67.83, '2024-08-10'),  -- Arnold Reuter buys 3 copies of 'A Love to Remember'
    (3, 1, 1, 20.99, 20.99, '2024-07-22'),  -- Louise Beckmann buys 1 copy of 'The Last Summer in Vienna'
    (4, 2, 2, 10.47, 20.94, '2024-09-10'),  -- Imke Zimmer buys 2 copies of 'A History of the Modern World'
    (5, 3, 1, 25.15, 25.15, '2024-08-30');  -- Anna-Luise Gerlach buys 1 copy of 'The Phantom of Blackwood Manor'
