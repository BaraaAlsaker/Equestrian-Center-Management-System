-- ============================================================
-- CS351 Database Project - Equestrian Center Management System
-- DBMS: MySQL 8.x (InnoDB)
--
-- This script:
--  1) Creates the database (IF NOT EXISTS)
--  2) Creates all tables with PK/FK + constraints
--  3) Adds triggers to enforce business rules:
--      - Horse type rules (School vs Boarding owner requirement)
--      - Stable capacity
--      - Trainer/Groom role validation
--      - Lesson time validity + arena schedule overlap prevention
--      - Boarding contract date rules + single active contract per horse
--      - Groom assignment overlap prevention
--  4) Creates useful views
--  5) Inserts meaningful sample data
--  6) Provides an "Example Queries Pack" (commented) 
--
-- Notes:
--  - No DROP statements are used.
--  - If you run this twice, CREATE IF NOT EXISTS prevents errors for DB,
--    but table creation will fail if tables already exist. Run once on a clean DB.
-- ============================================================

/* ------------------------------------------------------------
   0) Create & select database
------------------------------------------------------------ */
CREATE DATABASE IF NOT EXISTS CS351_EquestrianCenter
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE CS351_EquestrianCenter;


/* ------------------------------------------------------------
   1) Core reference tables
------------------------------------------------------------ */

-- OWNER: horse owners (for Boarding horses)
CREATE TABLE IF NOT EXISTS OWNER (
  OwnerID     INT AUTO_INCREMENT PRIMARY KEY,
  Name        VARCHAR(100) NOT NULL,
  Phone       VARCHAR(20)  NOT NULL,
  Email       VARCHAR(150) NOT NULL,
  CONSTRAINT uq_owner_email UNIQUE (Email)
) ENGINE=InnoDB;

-- STABLE: stables/barns/sections in the center
CREATE TABLE IF NOT EXISTS STABLE (
  StableID      INT AUTO_INCREMENT PRIMARY KEY,
  NameOrNumber  VARCHAR(50)  NOT NULL,
  Section       VARCHAR(50)  NOT NULL,
  Capacity      INT          NOT NULL,
  CONSTRAINT ck_stable_capacity CHECK (Capacity > 0),
  CONSTRAINT uq_stable_name_section UNIQUE (NameOrNumber, Section)
) ENGINE=InnoDB;

-- EMPLOYEE: trainers, grooms, caretakers, etc.
CREATE TABLE IF NOT EXISTS EMPLOYEE (
  EmployeeID  INT AUTO_INCREMENT PRIMARY KEY,
  Name        VARCHAR(100) NOT NULL,
  Role        VARCHAR(50)  NOT NULL,
  Phone       VARCHAR(20)  NOT NULL,
  CONSTRAINT uq_employee_phone UNIQUE (Phone)
) ENGINE=InnoDB;

-- RIDER: riders/students taking lessons
CREATE TABLE IF NOT EXISTS RIDER (
  RiderID  INT AUTO_INCREMENT PRIMARY KEY,
  Name     VARCHAR(100) NOT NULL,
  Phone    VARCHAR(20)  NOT NULL,
  Level    VARCHAR(30)  NOT NULL,
  CONSTRAINT uq_rider_phone UNIQUE (Phone)
) ENGINE=InnoDB;

-- ARENA: arenas used for lessons
CREATE TABLE IF NOT EXISTS ARENA (
  ArenaID  INT AUTO_INCREMENT PRIMARY KEY,
  Name     VARCHAR(100) NOT NULL,
  Type     VARCHAR(50)  NOT NULL,
  CONSTRAINT uq_arena_name UNIQUE (Name)
) ENGINE=InnoDB;


/* ------------------------------------------------------------
   2) Main business tables
------------------------------------------------------------ */

-- HORSE: horses (School or Boarding)
-- Rule:
--   - Type='School'   => OwnerID MUST be NULL
--   - Type='Boarding' => OwnerID MUST be NOT NULL
-- Horse is assigned to exactly one Stable (StableID NOT NULL).
CREATE TABLE IF NOT EXISTS HORSE (
  HorseID      INT AUTO_INCREMENT PRIMARY KEY,
  Name         VARCHAR(100) NOT NULL,
  Type         ENUM('School','Boarding') NOT NULL,
  Gender       ENUM('Male','Female') NOT NULL,
  DateOfBirth  DATE NOT NULL,
  OwnerID      INT NULL,
  StableID     INT NOT NULL,

 

  CONSTRAINT fk_horse_owner
    FOREIGN KEY (OwnerID) REFERENCES OWNER (OwnerID)
    ON UPDATE CASCADE
    ON DELETE SET NULL,

  CONSTRAINT fk_horse_stable
    FOREIGN KEY (StableID) REFERENCES STABLE (StableID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- BOARDING_CONTRACT: contract history (Option A: ContractID PK)
-- Business intent:
--   - A horse may have multiple contracts over time (history)
--   - A horse should have at most one ACTIVE contract at a time
CREATE TABLE IF NOT EXISTS BOARDING_CONTRACT (
  ContractID   INT AUTO_INCREMENT PRIMARY KEY,
  OwnerID      INT NOT NULL,
  HorseID      INT NOT NULL,
  StartDate    DATE NOT NULL,
  EndDate      DATE NOT NULL,
  MonthlyFee   DECIMAL(10,2) NOT NULL,
  Status       ENUM('Active','Expired','Cancelled') NOT NULL DEFAULT 'Active',

  

  CONSTRAINT fk_contract_owner
    FOREIGN KEY (OwnerID) REFERENCES OWNER (OwnerID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_contract_horse
    FOREIGN KEY (HorseID) REFERENCES HORSE (HorseID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT ck_contract_fee CHECK (MonthlyFee >= 0),
  CONSTRAINT ck_contract_dates CHECK (EndDate >= StartDate)
) ENGINE=InnoDB;

-- HORSE_GROOM_ASSIGNMENT: which groom is assigned to a horse (supports history)
-- Rule:
--   - GroomID must reference an EMPLOYEE with Role='Groom'
--   - A horse cannot have overlapping active assignments
CREATE TABLE IF NOT EXISTS HORSE_GROOM_ASSIGNMENT (
  AssignmentID  INT AUTO_INCREMENT PRIMARY KEY,
  HorseID       INT NOT NULL,
  GroomID       INT NOT NULL,
  StartDate     DATE NOT NULL,
  EndDate       DATE NULL,

  

  CONSTRAINT fk_groom_assign_horse
    FOREIGN KEY (HorseID) REFERENCES HORSE (HorseID)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_groom_assign_groom
    FOREIGN KEY (GroomID) REFERENCES EMPLOYEE (EmployeeID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT ck_groom_assign_dates CHECK (EndDate IS NULL OR EndDate >= StartDate)
) ENGINE=InnoDB;

-- LESSON: scheduled lessons in arenas taught by trainers
CREATE TABLE IF NOT EXISTS LESSON (
  LessonID    INT AUTO_INCREMENT PRIMARY KEY,
  LessonDate  DATE NOT NULL,
  StartTime   TIME NOT NULL,
  EndTime     TIME NOT NULL,
  Type        ENUM('Private','Group','Training') NOT NULL,
  TrainerID   INT NOT NULL,
  ArenaID     INT NOT NULL,

  INDEX idx_lesson_arena_date (ArenaID, LessonDate),
  INDEX idx_lesson_trainer_date (TrainerID, LessonDate),

  CONSTRAINT fk_lesson_trainer
    FOREIGN KEY (TrainerID) REFERENCES EMPLOYEE (EmployeeID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT fk_lesson_arena
    FOREIGN KEY (ArenaID) REFERENCES ARENA (ArenaID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT,

  CONSTRAINT ck_lesson_time CHECK (EndTime > StartTime)
) ENGINE=InnoDB;

-- LESSON_RIDER: many-to-many (riders attend lessons)
CREATE TABLE IF NOT EXISTS LESSON_RIDER (
  LessonID  INT NOT NULL,
  RiderID   INT NOT NULL,
  PRIMARY KEY (LessonID, RiderID),

  CONSTRAINT fk_lr_lesson
    FOREIGN KEY (LessonID) REFERENCES LESSON (LessonID)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_lr_rider
    FOREIGN KEY (RiderID) REFERENCES RIDER (RiderID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;

-- LESSON_HORSE: many-to-many (horses participate in lessons)
CREATE TABLE IF NOT EXISTS LESSON_HORSE (
  LessonID  INT NOT NULL,
  HorseID   INT NOT NULL,
  PRIMARY KEY (LessonID, HorseID),

  CONSTRAINT fk_lh_lesson
    FOREIGN KEY (LessonID) REFERENCES LESSON (LessonID)
    ON UPDATE CASCADE
    ON DELETE CASCADE,

  CONSTRAINT fk_lh_horse
    FOREIGN KEY (HorseID) REFERENCES HORSE (HorseID)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB;


/* ------------------------------------------------------------
   3) TRIGGERS: enforce business rules that CHECK can't enforce
------------------------------------------------------------ */
DELIMITER $$

/* ---- HORSE rules:
   - School horse must NOT have OwnerID
   - Boarding horse MUST have OwnerID
   - Stable capacity must not be exceeded
*/
CREATE TRIGGER trg_horse_before_insert
BEFORE INSERT ON HORSE
FOR EACH ROW
BEGIN
  DECLARE current_count INT;

  -- Rule 1: OwnerID based on Type
  IF NEW.Type = 'School' AND NEW.OwnerID IS NOT NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'School horses must not have an OwnerID (OwnerID must be NULL).';
  END IF;

  IF NEW.Type = 'Boarding' AND NEW.OwnerID IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Boarding horses must have an OwnerID (OwnerID cannot be NULL).';
  END IF;

  -- Rule 2: Stable capacity
  SELECT COUNT(*) INTO current_count
  FROM HORSE
  WHERE StableID = NEW.StableID;

  IF current_count >= (SELECT Capacity FROM STABLE WHERE StableID = NEW.StableID) THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Stable capacity exceeded: cannot assign more horses to this stable.';
  END IF;
END$$


CREATE TRIGGER trg_horse_before_update
BEFORE UPDATE ON HORSE
FOR EACH ROW
BEGIN
  DECLARE current_count INT;

  -- Rule 1: OwnerID based on Type
  IF NEW.Type = 'School' AND NEW.OwnerID IS NOT NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'School horses must not have an OwnerID (OwnerID must be NULL).';
  END IF;

  IF NEW.Type = 'Boarding' AND NEW.OwnerID IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Boarding horses must have an OwnerID (OwnerID cannot be NULL).';
  END IF;

  -- Rule 2: If stable changes, check capacity
  IF NEW.StableID <> OLD.StableID THEN
    SELECT COUNT(*) INTO current_count
    FROM HORSE
    WHERE StableID = NEW.StableID;

    IF current_count >= (SELECT Capacity FROM STABLE WHERE StableID = NEW.StableID) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Stable capacity exceeded: cannot move horse to this stable.';
    END IF;
  END IF;
END$$


/* ---- BOARDING_CONTRACT rules:
   - EndDate >= StartDate (already a CHECK; trigger adds clearer error)
   - MonthlyFee >= 0 (already a CHECK)
   - Only ONE active contract per horse at a time
     (prevent overlapping ACTIVE contract date ranges)
*/
CREATE TRIGGER trg_contract_before_insert
BEFORE INSERT ON BOARDING_CONTRACT
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;

  IF NEW.EndDate < NEW.StartDate THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Contract EndDate must be >= StartDate.';
  END IF;

  -- Only check overlap if inserting an ACTIVE contract
  IF NEW.Status = 'Active' THEN
    SELECT COUNT(*) INTO overlap_count
    FROM BOARDING_CONTRACT c
    WHERE c.HorseID = NEW.HorseID
      AND c.Status = 'Active'
      AND (NEW.StartDate <= c.EndDate AND NEW.EndDate >= c.StartDate);

    IF overlap_count > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Overlapping ACTIVE boarding contract detected for this horse.';
    END IF;
  END IF;
END$$


CREATE TRIGGER trg_contract_before_update
BEFORE UPDATE ON BOARDING_CONTRACT
FOR EACH ROW
BEGIN
  DECLARE overlap_count INT;

  IF NEW.EndDate < NEW.StartDate THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Contract EndDate must be >= StartDate.';
  END IF;

  -- If updated row becomes Active OR remains Active, ensure no overlaps (excluding itself)
  IF NEW.Status = 'Active' THEN
    SELECT COUNT(*) INTO overlap_count
    FROM BOARDING_CONTRACT c
    WHERE c.HorseID = NEW.HorseID
      AND c.Status = 'Active'
      AND c.ContractID <> OLD.ContractID
      AND (NEW.StartDate <= c.EndDate AND NEW.EndDate >= c.StartDate);

    IF overlap_count > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Overlapping ACTIVE boarding contract detected for this horse.';
    END IF;
  END IF;
END$$


/* ---- HORSE_GROOM_ASSIGNMENT rules:
   - GroomID must be an EMPLOYEE with Role='Groom'
   - Prevent overlapping assignments for the same HorseID
*/
CREATE TRIGGER trg_groom_assign_before_insert
BEFORE INSERT ON HORSE_GROOM_ASSIGNMENT
FOR EACH ROW
BEGIN
  DECLARE role_name VARCHAR(50);
  DECLARE overlap_count INT;

  SELECT Role INTO role_name
  FROM EMPLOYEE
  WHERE EmployeeID = NEW.GroomID;

  IF role_name IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Invalid GroomID: employee does not exist.';
  END IF;

  IF role_name <> 'Groom' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Assigned GroomID must reference an EMPLOYEE with Role = Groom.';
  END IF;

  -- Prevent overlap in assignments for the same horse
  SELECT COUNT(*) INTO overlap_count
  FROM HORSE_GROOM_ASSIGNMENT a
  WHERE a.HorseID = NEW.HorseID
    AND (NEW.StartDate <= COALESCE(a.EndDate, '9999-12-31')
         AND COALESCE(NEW.EndDate, '9999-12-31') >= a.StartDate);

  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Overlapping groom assignment detected for this horse.';
  END IF;
END$$


CREATE TRIGGER trg_groom_assign_before_update
BEFORE UPDATE ON HORSE_GROOM_ASSIGNMENT
FOR EACH ROW
BEGIN
  DECLARE role_name VARCHAR(50);
  DECLARE overlap_count INT;

  SELECT Role INTO role_name
  FROM EMPLOYEE
  WHERE EmployeeID = NEW.GroomID;

  IF role_name IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Invalid GroomID: employee does not exist.';
  END IF;

  IF role_name <> 'Groom' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Assigned GroomID must reference an EMPLOYEE with Role = Groom.';
  END IF;

  -- Prevent overlap in assignments for the same horse (excluding itself)
  SELECT COUNT(*) INTO overlap_count
  FROM HORSE_GROOM_ASSIGNMENT a
  WHERE a.HorseID = NEW.HorseID
    AND a.AssignmentID <> OLD.AssignmentID
    AND (NEW.StartDate <= COALESCE(a.EndDate, '9999-12-31')
         AND COALESCE(NEW.EndDate, '9999-12-31') >= a.StartDate);

  IF overlap_count > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Overlapping groom assignment detected for this horse.';
  END IF;
END$$


/* ---- LESSON rules:
   - EndTime > StartTime (already a CHECK; trigger gives clearer error)
   - TrainerID must reference EMPLOYEE with Role='Trainer'
   - Prevent overlapping arena bookings (same arena, same date, time overlap)
   - Optional: Prevent trainer from having overlapping lessons too (same trainer/date)
*/
CREATE TRIGGER trg_lesson_before_insert
BEFORE INSERT ON LESSON
FOR EACH ROW
BEGIN
  DECLARE role_name VARCHAR(50);
  DECLARE arena_overlap INT;
  DECLARE trainer_overlap INT;

  IF NEW.EndTime <= NEW.StartTime THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lesson EndTime must be greater than StartTime.';
  END IF;

  SELECT Role INTO role_name
  FROM EMPLOYEE
  WHERE EmployeeID = NEW.TrainerID;

  IF role_name IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Invalid TrainerID: employee does not exist.';
  END IF;

  IF role_name <> 'Trainer' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'TrainerID must reference an EMPLOYEE with Role = Trainer.';
  END IF;

  -- Arena overlap check
  SELECT COUNT(*) INTO arena_overlap
  FROM LESSON l
  WHERE l.ArenaID = NEW.ArenaID
    AND l.LessonDate = NEW.LessonDate
    AND (NEW.StartTime < l.EndTime AND NEW.EndTime > l.StartTime);

  IF arena_overlap > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Arena booking overlap: another lesson exists in this arena during the same time.';
  END IF;

  -- Trainer overlap check
  SELECT COUNT(*) INTO trainer_overlap
  FROM LESSON l
  WHERE l.TrainerID = NEW.TrainerID
    AND l.LessonDate = NEW.LessonDate
    AND (NEW.StartTime < l.EndTime AND NEW.EndTime > l.StartTime);

  IF trainer_overlap > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Trainer schedule overlap: trainer already has a lesson at this time.';
  END IF;
END$$


CREATE TRIGGER trg_lesson_before_update
BEFORE UPDATE ON LESSON
FOR EACH ROW
BEGIN
  DECLARE role_name VARCHAR(50);
  DECLARE arena_overlap INT;
  DECLARE trainer_overlap INT;

  IF NEW.EndTime <= NEW.StartTime THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Lesson EndTime must be greater than StartTime.';
  END IF;

  SELECT Role INTO role_name
  FROM EMPLOYEE
  WHERE EmployeeID = NEW.TrainerID;

  IF role_name IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Invalid TrainerID: employee does not exist.';
  END IF;

  IF role_name <> 'Trainer' THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'TrainerID must reference an EMPLOYEE with Role = Trainer.';
  END IF;

  -- Arena overlap check (exclude itself)
  SELECT COUNT(*) INTO arena_overlap
  FROM LESSON l
  WHERE l.ArenaID = NEW.ArenaID
    AND l.LessonDate = NEW.LessonDate
    AND l.LessonID <> OLD.LessonID
    AND (NEW.StartTime < l.EndTime AND NEW.EndTime > l.StartTime);

  IF arena_overlap > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Arena booking overlap: another lesson exists in this arena during the same time.';
  END IF;

  -- Trainer overlap check (exclude itself)
  SELECT COUNT(*) INTO trainer_overlap
  FROM LESSON l
  WHERE l.TrainerID = NEW.TrainerID
    AND l.LessonDate = NEW.LessonDate
    AND l.LessonID <> OLD.LessonID
    AND (NEW.StartTime < l.EndTime AND NEW.EndTime > l.StartTime);

  IF trainer_overlap > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Trainer schedule overlap: trainer already has a lesson at this time.';
  END IF;
END$$

DELIMITER ;


-- ------------------------------------------------------------
-- 4) VIEWS: make reporting easier (lab idea: CREATE VIEW)
-- ------------------------------------------------------------

/* View 1: Active boarding contracts */
CREATE OR REPLACE VIEW v_active_boarding_contracts AS
SELECT
  c.ContractID,
  c.HorseID,
  h.Name AS HorseName,
  c.OwnerID,
  o.Name AS OwnerName,
  c.StartDate,
  c.EndDate,
  c.MonthlyFee,
  c.Status
FROM BOARDING_CONTRACT c
JOIN HORSE h ON h.HorseID = c.HorseID
JOIN OWNER o ON o.OwnerID = c.OwnerID
WHERE c.Status = 'Active';

/* View 2: Contracts expiring soon (next 30 days) - used for UR notifications */
CREATE OR REPLACE VIEW v_contracts_expiring_soon AS
SELECT
  c.ContractID,
  o.Name AS OwnerName,
  o.Phone AS OwnerPhone,
  o.Email AS OwnerEmail,
  h.Name AS HorseName,
  c.EndDate,
  DATEDIFF(c.EndDate, CURDATE()) AS DaysRemaining
FROM BOARDING_CONTRACT c
JOIN OWNER o ON o.OwnerID = c.OwnerID
JOIN HORSE h ON h.HorseID = c.HorseID
WHERE c.Status = 'Active'
  AND c.EndDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 30 DAY);

/* View 3: Lesson schedule with arena + trainer names */
CREATE OR REPLACE VIEW v_lesson_schedule AS
SELECT
  l.LessonID,
  l.LessonDate,
  l.StartTime,
  l.EndTime,
  l.Type,
  a.Name AS ArenaName,
  e.Name AS TrainerName
FROM LESSON l
JOIN ARENA a   ON a.ArenaID = l.ArenaID
JOIN EMPLOYEE e ON e.EmployeeID = l.TrainerID;

/* View 4: Rider lesson history */
CREATE OR REPLACE VIEW v_rider_lesson_history AS
SELECT
  r.RiderID,
  r.Name AS RiderName,
  l.LessonID,
  l.LessonDate,
  l.StartTime,
  l.EndTime,
  l.Type,
  a.Name AS ArenaName,
  e.Name AS TrainerName
FROM RIDER r
JOIN LESSON_RIDER lr ON lr.RiderID = r.RiderID
JOIN LESSON l        ON l.LessonID = lr.LessonID
JOIN ARENA a         ON a.ArenaID = l.ArenaID
JOIN EMPLOYEE e      ON e.EmployeeID = l.TrainerID;

/* View 5: Current groom assignment (latest assignment with EndDate IS NULL) */
CREATE OR REPLACE VIEW v_current_groom_per_horse AS
SELECT
  h.HorseID,
  h.Name AS HorseName,
  a.GroomID,
  e.Name AS GroomName,
  a.StartDate
FROM HORSE h
LEFT JOIN HORSE_GROOM_ASSIGNMENT a
  ON a.HorseID = h.HorseID AND a.EndDate IS NULL
LEFT JOIN EMPLOYEE e
  ON e.EmployeeID = a.GroomID;


-- ------------------------------------------------------------
-- 5) SAMPLE DATA (meaningful demo data)
-- ------------------------------------------------------------

/* Owners */
INSERT INTO OWNER (Name, Phone, Email) VALUES
('Ahmed Al-Salem', '0501112223', 'ahmed.alsalem@example.com'),
('Sara Al-Harbi',  '0504445556', 'sara.harbi@example.com'),
('Fahad Al-Otaibi','0507778889', 'fahad.otaibi@example.com');

/* Stables */
INSERT INTO STABLE (NameOrNumber, Section, Capacity) VALUES
('Stable-A', 'North', 3),
('Stable-B', 'North', 2),
('Stable-C', 'South', 4);

/* Employees (include at least Trainer and Groom roles) */
INSERT INTO EMPLOYEE (Name, Role, Phone) VALUES
('Majed Trainer',  'Trainer', '0551002001'),
('Lina Trainer',   'Trainer', '0551002002'),
('Noura Groom',    'Groom',   '0551003001'),
('Omar Groom',     'Groom',   '0551003002'),
('Saad Manager',   'Manager', '0551004001');

/* Riders */
INSERT INTO RIDER (Name, Phone, Level) VALUES
('Baraa',     '0560001111', 'Beginner'),
('Hanan',     '0560002222', 'Intermediate'),
('Khalid',    '0560003333', 'Advanced'),
('Reem',      '0560004444', 'Beginner');

/* Arenas */
INSERT INTO ARENA (Name, Type) VALUES
('Arena 1', 'Indoor'),
('Arena 2', 'Outdoor'),
('Arena 3', 'Training Track');

/* Horses
   - School horses => OwnerID NULL
   - Boarding horses => OwnerID NOT NULL
*/
INSERT INTO HORSE (Name, Type, Gender, DateOfBirth, OwnerID, StableID) VALUES
('Thunder', 'School',  'Male',   '2016-05-10', NULL, 1),
('Bella',   'School',  'Female', '2017-08-22', NULL, 1),
('Spirit',  'Boarding','Male',   '2015-03-15', 1,    2),
('Daisy',   'Boarding','Female', '2018-11-01', 2,    2),
('Rocky',   'Boarding','Male',   '2014-02-20', 3,    3);

/* Groom assignments (history-capable)
   EndDate NULL means "current"
*/
INSERT INTO HORSE_GROOM_ASSIGNMENT (HorseID, GroomID, StartDate, EndDate) VALUES
(1, 3, '2025-09-01', NULL),
(2, 4, '2025-09-01', NULL),
(3, 3, '2025-09-15', NULL),
(4, 4, '2025-09-15', NULL),
(5, 3, '2025-10-01', NULL);

/* Boarding contracts (history)
   We insert active contracts without overlap per horse
*/
INSERT INTO BOARDING_CONTRACT (OwnerID, HorseID, StartDate, EndDate, MonthlyFee, Status) VALUES
(1, 3, '2025-09-01', '2026-08-31', 1500.00, 'Active'),
(2, 4, '2025-10-01', '2026-09-30', 1400.00, 'Active'),
(3, 5, '2025-07-01', '2026-06-30', 1600.00, 'Active');

/* Lessons (trainer role validated + no arena overlap)
   Times must not overlap for same arena/date and same trainer/date.
*/
INSERT INTO LESSON (LessonDate, StartTime, EndTime, Type, TrainerID, ArenaID) VALUES
('2025-11-10', '16:00:00', '17:00:00', 'Group',   1, 1),
('2025-11-10', '17:30:00', '18:30:00', 'Private', 1, 1),
('2025-11-11', '16:00:00', '17:00:00', 'Training',2, 3);

-- Riders attend lessons
INSERT INTO LESSON_RIDER (LessonID, RiderID) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 4);

-- Horses participate in lessons
INSERT INTO LESSON_HORSE (LessonID, HorseID) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 5);


/* ------------------------------------------------------------
   6) EXAMPLE QUERIES PACK 
   - Use a mix of WHERE, ORDER BY, LIKE, BETWEEN, IN, IS NULL, DISTINCT, ALIAS
   - Aggregates: COUNT, AVG, MAX, MIN, SUM
   - JOINs, Views, GROUP BY, HAVING, Subqueries
   - Set operations (UNION / UNION ALL)
   
------------------------------------------------------------ */

-- =========================
-- OWNER (5 queries + aggregates)
-- =========================

-- Q1: List all owners (SELECT ALL)
-- SELECT * FROM OWNER;

-- Q2: Find owners by name pattern (LIKE)
-- SELECT OwnerID, Name, Email FROM OWNER WHERE Name LIKE '%Al-%' ORDER BY Name;

-- Q3: Find a specific owner by email
-- SELECT * FROM OWNER WHERE Email = 'sara.harbi@example.com';

-- Q4: Owners who have at least one active contract (JOIN)
-- SELECT DISTINCT o.OwnerID, o.Name
-- FROM OWNER o
-- JOIN BOARDING_CONTRACT c ON c.OwnerID = o.OwnerID
-- WHERE c.Status='Active';

-- Q5: Owners with contracts expiring soon (VIEW)
-- SELECT * FROM v_contracts_expiring_soon ORDER BY DaysRemaining;

-- Aggregate A1: Count contracts per owner (GROUP BY)
-- SELECT o.OwnerID, o.Name, COUNT(c.ContractID) AS TotalContracts
-- FROM OWNER o
-- LEFT JOIN BOARDING_CONTRACT c ON c.OwnerID = o.OwnerID
-- GROUP BY o.OwnerID, o.Name
-- ORDER BY TotalContracts DESC;

-- Aggregate A2: Average monthly fee per owner (AVG)
-- SELECT o.OwnerID, o.Name, AVG(c.MonthlyFee) AS AvgFee
-- FROM OWNER o
-- JOIN BOARDING_CONTRACT c ON c.OwnerID = o.OwnerID
-- GROUP BY o.OwnerID, o.Name;


-- =========================
-- STABLE (5 queries + aggregates)
-- =========================

-- Q1: Show stables
-- SELECT * FROM STABLE;

-- Q2: Show horses per stable (JOIN)
-- SELECT s.StableID, s.NameOrNumber, s.Section, h.HorseID, h.Name AS HorseName
-- FROM STABLE s
-- LEFT JOIN HORSE h ON h.StableID = s.StableID
-- ORDER BY s.StableID, h.HorseID;

-- Q3: Stables in North section
-- SELECT * FROM STABLE WHERE Section='North' ORDER BY NameOrNumber;

-- Q4: Stables with capacity BETWEEN 2 and 4
-- SELECT * FROM STABLE WHERE Capacity BETWEEN 2 AND 4;

-- Q5: Find stables that currently have NO horses (IS NULL)
-- SELECT s.*
-- FROM STABLE s
-- LEFT JOIN HORSE h ON h.StableID = s.StableID
-- WHERE h.HorseID IS NULL;

-- Aggregate A1: Count horses per stable (COUNT)
-- SELECT s.StableID, s.NameOrNumber, COUNT(h.HorseID) AS HorsesCount
-- FROM STABLE s
-- LEFT JOIN HORSE h ON h.StableID = s.StableID
-- GROUP BY s.StableID, s.NameOrNumber;

-- Aggregate A2: Remaining capacity per stable
-- SELECT s.StableID, s.NameOrNumber,
--        s.Capacity - COUNT(h.HorseID) AS RemainingSlots
-- FROM STABLE s
-- LEFT JOIN HORSE h ON h.StableID = s.StableID
-- GROUP BY s.StableID, s.NameOrNumber, s.Capacity
-- HAVING RemainingSlots >= 0;


-- =========================
-- EMPLOYEE (5 queries + aggregates)
-- =========================

-- Q1: List all employees
-- SELECT * FROM EMPLOYEE;

-- Q2: List only trainers
-- SELECT * FROM EMPLOYEE WHERE Role='Trainer';

-- Q3: List only grooms
-- SELECT * FROM EMPLOYEE WHERE Role='Groom';

-- Q4: Employees whose name starts with 'M'
-- SELECT * FROM EMPLOYEE WHERE Name LIKE 'M%';

-- Q5: Trainers teaching lesson schedule (JOIN)
-- SELECT e.EmployeeID, e.Name AS TrainerName, l.LessonDate, l.StartTime, l.EndTime
-- FROM EMPLOYEE e
-- JOIN LESSON l ON l.TrainerID = e.EmployeeID
-- WHERE e.Role='Trainer'
-- ORDER BY l.LessonDate, l.StartTime;

-- Aggregate A1: Count lessons per trainer
-- SELECT e.EmployeeID, e.Name AS TrainerName, COUNT(l.LessonID) AS LessonsCount
-- FROM EMPLOYEE e
-- LEFT JOIN LESSON l ON l.TrainerID = e.EmployeeID
-- WHERE e.Role='Trainer'
-- GROUP BY e.EmployeeID, e.Name;

-- Aggregate A2: Count horses assigned per groom (current assignments)
-- SELECT e.EmployeeID, e.Name AS GroomName, COUNT(a.AssignmentID) AS HorsesAssigned
-- FROM EMPLOYEE e
-- LEFT JOIN HORSE_GROOM_ASSIGNMENT a
--   ON a.GroomID = e.EmployeeID AND a.EndDate IS NULL
-- WHERE e.Role='Groom'
-- GROUP BY e.EmployeeID, e.Name;


-- =========================
-- RIDER (5 queries + aggregates)
-- =========================

-- Q1: List riders
-- SELECT * FROM RIDER;

-- Q2: Riders by level
-- SELECT * FROM RIDER WHERE Level='Beginner' ORDER BY Name;

-- Q3: Riders whose phone is NOT NULL (example)
-- SELECT RiderID, Name, Phone FROM RIDER WHERE Phone IS NOT NULL;

-- Q4: Rider lesson history (VIEW)
-- SELECT * FROM v_rider_lesson_history WHERE RiderName='Baraa' ORDER BY LessonDate;

-- Q5: Riders attending a specific lesson (JOIN)
-- SELECT l.LessonID, r.RiderID, r.Name
-- FROM LESSON l
-- JOIN LESSON_RIDER lr ON lr.LessonID = l.LessonID
-- JOIN RIDER r ON r.RiderID = lr.RiderID
-- WHERE l.LessonID = 1;

-- Aggregate A1: Count lessons per rider
-- SELECT r.RiderID, r.Name, COUNT(lr.LessonID) AS LessonsAttended
-- FROM RIDER r
-- LEFT JOIN LESSON_RIDER lr ON lr.RiderID = r.RiderID
-- GROUP BY r.RiderID, r.Name;

-- Aggregate A2: Count riders by level
-- SELECT Level, COUNT(*) AS RidersCount
-- FROM RIDER
-- GROUP BY Level;


-- =========================
-- ARENA (5 queries + aggregates)
-- =========================

-- Q1: List arenas
-- SELECT * FROM ARENA;

-- Q2: Indoor arenas
-- SELECT * FROM ARENA WHERE Type='Indoor';

-- Q3: Arena schedule (VIEW)
-- SELECT * FROM v_lesson_schedule WHERE ArenaName='Arena 1' ORDER BY LessonDate, StartTime;

-- Q4: Arenas with no lessons scheduled (LEFT JOIN + IS NULL)
-- SELECT a.*
-- FROM ARENA a
-- LEFT JOIN LESSON l ON l.ArenaID = a.ArenaID
-- WHERE l.LessonID IS NULL;

-- Q5: Distinct arena types
-- SELECT DISTINCT Type FROM ARENA ORDER BY Type;

-- Aggregate A1: Number of lessons per arena
-- SELECT a.ArenaID, a.Name, COUNT(l.LessonID) AS LessonsCount
-- FROM ARENA a
-- LEFT JOIN LESSON l ON l.ArenaID = a.ArenaID
-- GROUP BY a.ArenaID, a.Name;

-- Aggregate A2: Earliest and latest lesson time per arena per day
-- SELECT l.ArenaID, l.LessonDate,
--        MIN(l.StartTime) AS FirstStart,
--        MAX(l.EndTime)   AS LastEnd
-- FROM LESSON l
-- GROUP BY l.ArenaID, l.LessonDate;


-- =========================
-- HORSE (5 queries + aggregates)
-- =========================

-- Q1: List all horses
-- SELECT * FROM HORSE;

-- Q2: List school horses (OwnerID should be NULL)
-- SELECT HorseID, Name FROM HORSE WHERE Type='School';

-- Q3: List boarding horses with owner names (JOIN)
-- SELECT h.HorseID, h.Name AS HorseName, o.Name AS OwnerName
-- FROM HORSE h
-- JOIN OWNER o ON o.OwnerID = h.OwnerID
-- WHERE h.Type='Boarding'
-- ORDER BY OwnerName;

-- Q4: Horses in a specific stable
-- SELECT HorseID, Name FROM HORSE WHERE StableID = 2 ORDER BY Name;

-- Q5: Current groom per horse (VIEW)
-- SELECT * FROM v_current_groom_per_horse ORDER BY HorseID;

-- Aggregate A1: Count horses by type
-- SELECT Type, COUNT(*) AS HorsesCount
-- FROM HORSE
-- GROUP BY Type;

-- Aggregate A2: Average age by type (approx using YEAR)
-- SELECT Type, AVG(TIMESTAMPDIFF(YEAR, DateOfBirth, CURDATE())) AS AvgAgeYears
-- FROM HORSE
-- GROUP BY Type;


-- =========================
-- BOARDING_CONTRACT (5 queries + aggregates)
-- =========================

-- Q1: List all contracts
-- SELECT * FROM BOARDING_CONTRACT;

-- Q2: List active contracts (VIEW)
-- SELECT * FROM v_active_boarding_contracts ORDER BY EndDate;

-- Q3: Contracts expiring soon (VIEW)
-- SELECT * FROM v_contracts_expiring_soon ORDER BY DaysRemaining;

-- Q4: Contract history for one horse
-- SELECT * FROM BOARDING_CONTRACT WHERE HorseID = 3 ORDER BY StartDate DESC;

-- Q5: Cancel a contract (UPDATE example)
-- UPDATE BOARDING_CONTRACT SET Status='Cancelled'
-- WHERE ContractID = 1;

-- Aggregate A1: Total revenue (SUM monthly fee) for active contracts
-- SELECT SUM(MonthlyFee) AS TotalMonthlyRevenue
-- FROM BOARDING_CONTRACT
-- WHERE Status='Active';

-- Aggregate A2: Max/min fee
-- SELECT MAX(MonthlyFee) AS MaxFee, MIN(MonthlyFee) AS MinFee
-- FROM BOARDING_CONTRACT;


-- =========================
-- LESSON / LESSON_RIDER / LESSON_HORSE (joins, grouping, subqueries)
-- =========================

-- Q1: List lessons (VIEW)
-- SELECT * FROM v_lesson_schedule ORDER BY LessonDate, StartTime;

-- Q2: Show lesson participants (JOIN)
-- SELECT l.LessonID, l.LessonDate, r.Name AS RiderName
-- FROM LESSON l
-- JOIN LESSON_RIDER lr ON lr.LessonID = l.LessonID
-- JOIN RIDER r ON r.RiderID = lr.RiderID
-- ORDER BY l.LessonID, r.Name;

-- Q3: Show horses in each lesson (JOIN)
-- SELECT l.LessonID, l.LessonDate, h.Name AS HorseName
-- FROM LESSON l
-- JOIN LESSON_HORSE lh ON lh.LessonID = l.LessonID
-- JOIN HORSE h ON h.HorseID = lh.HorseID
-- ORDER BY l.LessonID, h.Name;

-- Q4: Lessons on a date with time range (BETWEEN)
-- SELECT * FROM LESSON
-- WHERE LessonDate='2025-11-10' AND StartTime BETWEEN '15:00:00' AND '18:00:00';

-- Q5: Find riders not registered in any lesson (LEFT JOIN + IS NULL)
-- SELECT r.*
-- FROM RIDER r
-- LEFT JOIN LESSON_RIDER lr ON lr.RiderID = r.RiderID
-- WHERE lr.LessonID IS NULL;

-- Aggregate A1: Count riders per lesson
-- SELECT l.LessonID, l.LessonDate, COUNT(lr.RiderID) AS RiderCount
-- FROM LESSON l
-- LEFT JOIN LESSON_RIDER lr ON lr.LessonID = l.LessonID
-- GROUP BY l.LessonID, l.LessonDate;

-- Aggregate A2: Count horses per lesson
-- SELECT l.LessonID, l.LessonDate, COUNT(lh.HorseID) AS HorseCount
-- FROM LESSON l
-- LEFT JOIN LESSON_HORSE lh ON lh.LessonID = l.LessonID
-- GROUP BY l.LessonID, l.LessonDate;

-- Subquery example (Lab 7 idea): Trainers who teach more than average lessons
-- SELECT t.EmployeeID, t.Name, COUNT(l.LessonID) AS LessonCount
-- FROM EMPLOYEE t
-- JOIN LESSON l ON l.TrainerID = t.EmployeeID
-- WHERE t.Role='Trainer'
-- GROUP BY t.EmployeeID, t.Name
-- HAVING COUNT(l.LessonID) >
--   (SELECT AVG(cnt) FROM (
--      SELECT COUNT(*) AS cnt
--      FROM LESSON
--      GROUP BY TrainerID
--    ) x);

-- Set operation example (Lab 9 idea): All unique cities doesn't apply here, so we demonstrate UNION on people names:
-- (List all unique names of owners and riders)
-- SELECT Name FROM OWNER
-- UNION
-- SELECT Name FROM RIDER;


-- ============================================================
-- End of script
-- ============================================================
