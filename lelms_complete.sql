-- ============================================================================
-- LABORATORY EQUIPMENT LIFECYCLE & MAINTENANCE SYSTEM (LELMS)
-- Fixed All-in-One MySQL Workbench Script (Zero Error 3823 / Safe-Update Ready)
-- ============================================================================

SET SQL_SAFE_UPDATES = 0;

DROP DATABASE IF EXISTS lab_equipment_lms;
CREATE DATABASE lab_equipment_lms
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE lab_equipment_lms;

-- ============================================================================
-- 1. CREATE ALL 24 TABLES IN STRICT DEPENDENCY ORDER
-- ============================================================================

-- [1/24] department (Module A)
CREATE TABLE department (
    dept_id INT AUTO_INCREMENT PRIMARY KEY,
    dept_code VARCHAR(15) NOT NULL UNIQUE,
    dept_name VARCHAR(100) NOT NULL UNIQUE,
    building_block VARCHAR(40) NOT NULL
) ENGINE=InnoDB;

-- [2/24] app_user (Module B - Supertype)
CREATE TABLE app_user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    role ENUM('TECHNICIAN', 'FACULTY', 'STUDENT') NOT NULL COMMENT 'discriminator',
    dept_id INT NULL,
    CONSTRAINT fk_appuser_dept FOREIGN KEY (dept_id)
        REFERENCES department(dept_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- [3/24] technician (Module B - Subtype of app_user)
CREATE TABLE technician (
    user_id INT PRIMARY KEY,
    specialization VARCHAR(60) NOT NULL,
    certification VARCHAR(80) NOT NULL,
    CONSTRAINT fk_tech_user FOREIGN KEY (user_id)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [4/24] faculty (Module B - Subtype of app_user)
CREATE TABLE faculty (
    user_id INT PRIMARY KEY,
    designation VARCHAR(60) NOT NULL,
    CONSTRAINT fk_faculty_user FOREIGN KEY (user_id)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [5/24] student (Module B - Subtype of app_user)
CREATE TABLE student (
    user_id INT PRIMARY KEY,
    roll_no VARCHAR(20) NOT NULL UNIQUE,
    program VARCHAR(60) NOT NULL,
    year_of_study TINYINT NOT NULL,
    CONSTRAINT chk_student_year CHECK (year_of_study BETWEEN 1 AND 6),
    CONSTRAINT fk_student_user FOREIGN KEY (user_id)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [6/24] laboratory (Module A)
CREATE TABLE laboratory (
    lab_id INT AUTO_INCREMENT PRIMARY KEY,
    lab_code VARCHAR(20) NOT NULL UNIQUE,
    lab_name VARCHAR(100) NOT NULL,
    room_no VARCHAR(20) NOT NULL,
    floor_no TINYINT NOT NULL,
    capacity INT NOT NULL,
    dept_id INT NOT NULL,
    incharge_faculty_id INT NULL,
    CONSTRAINT chk_lab_capacity CHECK (capacity > 0),
    CONSTRAINT fk_lab_dept FOREIGN KEY (dept_id)
        REFERENCES department(dept_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_lab_faculty FOREIGN KEY (incharge_faculty_id)
        REFERENCES faculty(user_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- [7/24] vendor (Module A)
CREATE TABLE vendor (
    vendor_id INT AUTO_INCREMENT PRIMARY KEY,
    vendor_name VARCHAR(120) NOT NULL,
    gst_tax_id VARCHAR(30) NOT NULL UNIQUE,
    contact_person VARCHAR(80) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL,
    street VARCHAR(120) NOT NULL,
    city VARCHAR(60) NOT NULL,
    state VARCHAR(60) NOT NULL
) ENGINE=InnoDB;

-- [8/24] equipment_category (Module A)
CREATE TABLE equipment_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(80) NOT NULL UNIQUE,
    description VARCHAR(255) NULL
) ENGINE=InnoDB;

-- [9/24] equipment_model (Module A)
CREATE TABLE equipment_model (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    category_id INT NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    manufacturer VARCHAR(100) NOT NULL,
    expected_lifespan_years INT NOT NULL,
    rated_service_hours INT NOT NULL,
    power_rating_watts DECIMAL(8,2) NULL,
    CONSTRAINT uq_mfg_model UNIQUE (manufacturer, model_name),
    CONSTRAINT chk_model_specs CHECK (expected_lifespan_years > 0 AND rated_service_hours > 0),
    CONSTRAINT fk_model_category FOREIGN KEY (category_id)
        REFERENCES equipment_category(category_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [10/24] purchase_order (Module A)
CREATE TABLE purchase_order (
    po_id INT AUTO_INCREMENT PRIMARY KEY,
    po_number VARCHAR(30) NOT NULL UNIQUE,
    vendor_id INT NOT NULL,
    lab_id INT NOT NULL,
    order_date DATE NOT NULL,
    delivery_date DATE NULL,
    po_status ENUM('ORDERED', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED') NOT NULL DEFAULT 'ORDERED',
    CONSTRAINT chk_po_dates CHECK (delivery_date IS NULL OR delivery_date >= order_date),
    CONSTRAINT fk_po_vendor FOREIGN KEY (vendor_id)
        REFERENCES vendor(vendor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_po_lab FOREIGN KEY (lab_id)
        REFERENCES laboratory(lab_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [11/24] po_item (Module A - Weak Entity on purchase_order)
CREATE TABLE po_item (
    po_id INT NOT NULL,
    item_no INT NOT NULL,
    model_id INT NOT NULL,
    quantity_ordered INT NOT NULL,
    unit_price DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (po_id, item_no),
    CONSTRAINT chk_poitem_vals CHECK (quantity_ordered > 0 AND unit_price >= 0),
    CONSTRAINT fk_poitem_po FOREIGN KEY (po_id)
        REFERENCES purchase_order(po_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_poitem_model FOREIGN KEY (model_id)
        REFERENCES equipment_model(model_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [12/24] equipment_unit (Module A - Central Entity)
CREATE TABLE equipment_unit (
    unit_id INT AUTO_INCREMENT PRIMARY KEY,
    asset_tag VARCHAR(30) NOT NULL UNIQUE,
    serial_number VARCHAR(60) NOT NULL UNIQUE,
    model_id INT NOT NULL,
    po_id INT NULL,
    po_item_no INT NULL,
    current_lab_id INT NOT NULL,
    acquisition_date DATE NOT NULL,
    acquisition_cost DECIMAL(12,2) NOT NULL,
    salvage_estimate DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    cumulative_usage_hours DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    status ENUM('AVAILABLE', 'IN_USE', 'UNDER_MAINTENANCE', 'CALIBRATION_DUE', 'DECOMMISSIONED') NOT NULL DEFAULT 'AVAILABLE',
    CONSTRAINT chk_unit_cost CHECK (acquisition_cost >= 0 AND salvage_estimate >= 0 AND salvage_estimate <= acquisition_cost),
    CONSTRAINT chk_unit_hours CHECK (cumulative_usage_hours >= 0),
    CONSTRAINT fk_unit_model FOREIGN KEY (model_id)
        REFERENCES equipment_model(model_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_unit_poitem FOREIGN KEY (po_id, po_item_no)
        REFERENCES po_item(po_id, item_no)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_unit_lab FOREIGN KEY (current_lab_id)
        REFERENCES laboratory(lab_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [13/24] warranty_contract (Module A - Weak Entity on equipment_unit)
CREATE TABLE warranty_contract (
    unit_id INT NOT NULL,
    warranty_seq INT NOT NULL,
    warranty_id INT AUTO_INCREMENT UNIQUE,
    vendor_id INT NOT NULL,
    contract_code VARCHAR(40) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    coverage_terms VARCHAR(255) NOT NULL,
    PRIMARY KEY (unit_id, warranty_seq),
    CONSTRAINT chk_warranty_dates CHECK (end_date >= start_date),
    CONSTRAINT fk_warranty_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_warranty_vendor FOREIGN KEY (vendor_id)
        REFERENCES vendor(vendor_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [14/24] lab_transfer (Module A - Fixed for MySQL Error 3823; diff-lab rule enforced via trigger)
CREATE TABLE lab_transfer (
    transfer_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    from_lab_id INT NOT NULL,
    to_lab_id INT NOT NULL,
    transfer_date DATE NOT NULL,
    reason VARCHAR(200) NOT NULL,
    CONSTRAINT fk_transfer_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_transfer_from_lab FOREIGN KEY (from_lab_id)
        REFERENCES laboratory(lab_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_transfer_to_lab FOREIGN KEY (to_lab_id)
        REFERENCES laboratory(lab_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [15/24] decommission_record (Module A)
CREATE TABLE decommission_record (
    decommission_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL UNIQUE,
    approved_by INT NOT NULL,
    decommission_date DATE NOT NULL,
    reason VARCHAR(255) NOT NULL,
    disposal_method ENUM('SCRAPPED', 'AUCTIONED', 'DONATED', 'RECYCLED', 'RETURNED_TO_VENDOR') NOT NULL,
    salvage_value DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_decomm_salvage CHECK (salvage_value >= 0),
    CONSTRAINT fk_decomm_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_decomm_user FOREIGN KEY (approved_by)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [16/24] issue_record (Module B)
CREATE TABLE issue_record (
    issue_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    borrower_id INT NOT NULL,
    issued_by INT NOT NULL,
    lab_id INT NOT NULL,
    issue_date DATETIME NOT NULL,
    expected_return_date DATE NOT NULL,
    actual_return_date DATETIME NULL,
    purpose VARCHAR(200) NOT NULL,
    return_condition ENUM('GOOD', 'MINOR_WEAR', 'DAMAGED', 'LOST') NULL,
    hours_used DECIMAL(8,2) NULL,
    CONSTRAINT chk_issue_hours CHECK (hours_used IS NULL OR hours_used >= 0),
    CONSTRAINT fk_issue_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_issue_borrower FOREIGN KEY (borrower_id)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_issue_issuer FOREIGN KEY (issued_by)
        REFERENCES app_user(user_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_issue_lab FOREIGN KEY (lab_id)
        REFERENCES laboratory(lab_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [17/24] audit_log (Module B)
CREATE TABLE audit_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    old_status VARCHAR(20) NULL,
    new_status VARCHAR(20) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    changed_by VARCHAR(100) NOT NULL,
    CONSTRAINT fk_audit_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [18/24] maintenance_plan (Module C)
CREATE TABLE maintenance_plan (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    interval_days INT NOT NULL,
    interval_hours INT NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE NULL,
    CONSTRAINT chk_plan_intervals CHECK (interval_days > 0 AND interval_hours > 0),
    CONSTRAINT chk_plan_dates CHECK (effective_to IS NULL OR effective_to >= effective_from),
    CONSTRAINT fk_plan_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [19/24] work_order (Module C - Supertype)
CREATE TABLE work_order (
    wo_id INT AUTO_INCREMENT PRIMARY KEY,
    unit_id INT NOT NULL,
    wo_type ENUM('PREVENTIVE', 'CORRECTIVE', 'CALIBRATION') NOT NULL COMMENT 'discriminator',
    wo_status ENUM('OPEN', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'OPEN',
    technician_id INT NULL,
    vendor_id INT NULL,
    created_date DATE NOT NULL,
    due_date DATE NOT NULL,
    start_date DATE NULL,
    completion_date DATE NULL,
    service_cost DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    remarks VARCHAR(255) NULL,
    CONSTRAINT chk_wo_cost CHECK (service_cost >= 0),
    CONSTRAINT chk_wo_dates CHECK (due_date >= created_date AND (completion_date IS NULL OR start_date IS NULL OR completion_date >= start_date)),
    CONSTRAINT fk_wo_unit FOREIGN KEY (unit_id)
        REFERENCES equipment_unit(unit_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_wo_tech FOREIGN KEY (technician_id)
        REFERENCES technician(user_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_wo_vendor FOREIGN KEY (vendor_id)
        REFERENCES vendor(vendor_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- [20/24] preventive_wo (Module C - Subtype of work_order)
CREATE TABLE preventive_wo (
    wo_id INT PRIMARY KEY,
    plan_id INT NOT NULL,
    usage_hours_at_service DECIMAL(10,2) NOT NULL,
    checklist_notes TEXT NULL,
    CONSTRAINT fk_prevwo_wo FOREIGN KEY (wo_id)
        REFERENCES work_order(wo_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_prevwo_plan FOREIGN KEY (plan_id)
        REFERENCES maintenance_plan(plan_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- [21/24] corrective_wo (Module C - Subtype of work_order)
CREATE TABLE corrective_wo (
    wo_id INT PRIMARY KEY,
    fault_description TEXT NOT NULL,
    severity ENUM('LOW', 'MEDIUM', 'HIGH', 'CRITICAL') NOT NULL,
    CONSTRAINT fk_corrwo_wo FOREIGN KEY (wo_id)
        REFERENCES work_order(wo_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [22/24] calibration_wo (Module C - Subtype of work_order)
CREATE TABLE calibration_wo (
    wo_id INT PRIMARY KEY,
    certificate_no VARCHAR(40) NOT NULL UNIQUE,
    reference_standard VARCHAR(80) NOT NULL,
    result ENUM('PASS', 'FAIL', 'ADJUSTED') NOT NULL,
    valid_until DATE NOT NULL,
    CONSTRAINT fk_calwo_wo FOREIGN KEY (wo_id)
        REFERENCES work_order(wo_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB;

-- [23/24] spare_part (Module C)
CREATE TABLE spare_part (
    part_id INT AUTO_INCREMENT PRIMARY KEY,
    part_name VARCHAR(80) NOT NULL,
    part_number VARCHAR(40) NOT NULL UNIQUE,
    stock_qty INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 5,
    unit_cost DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_part_stock CHECK (stock_qty >= 0 AND reorder_level >= 0 AND unit_cost >= 0)
) ENGINE=InnoDB;

-- [24/24] work_order_part (Module C - M:N Associative Table)
CREATE TABLE work_order_part (
    wo_id INT NOT NULL,
    part_id INT NOT NULL,
    quantity_used INT NOT NULL,
    unit_cost_at_use DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (wo_id, part_id),
    CONSTRAINT chk_wopart_qty CHECK (quantity_used > 0 AND unit_cost_at_use >= 0),
    CONSTRAINT fk_wopart_wo FOREIGN KEY (wo_id)
        REFERENCES work_order(wo_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_wopart_part FOREIGN KEY (part_id)
        REFERENCES spare_part(part_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================================
-- 2. SECONDARY INDEXES FOR QUERY PERFORMANCE
-- ============================================================================
CREATE INDEX idx_unit_status_lab ON equipment_unit(status, current_lab_id);
CREATE INDEX idx_issue_borrower_dates ON issue_record(borrower_id, issue_date, actual_return_date);
CREATE INDEX idx_wo_unit_status_type ON work_order(unit_id, wo_status, wo_type);
CREATE INDEX idx_audit_unit_time ON audit_log(unit_id, changed_at);

-- ============================================================================
-- 3. TRIGGERS, FUNCTIONS, STORED PROCEDURES & VIEWS
-- ============================================================================

DELIMITER $$

-- Audit initial creation & status changes on equipment_unit
CREATE TRIGGER trg_equipment_unit_after_insert
AFTER INSERT ON equipment_unit
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (unit_id, old_status, new_status, changed_at, changed_by)
    VALUES (NEW.unit_id, NULL, NEW.status, CURRENT_TIMESTAMP, COALESCE(@app_actor, CURRENT_USER()));
END$$

CREATE TRIGGER trg_equipment_unit_after_status_update
AFTER UPDATE ON equipment_unit
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_log (unit_id, old_status, new_status, changed_at, changed_by)
        VALUES (NEW.unit_id, OLD.status, NEW.status, CURRENT_TIMESTAMP, COALESCE(@app_actor, CURRENT_USER()));
    END IF;
END$$

-- Enforce EER Disjoint Specialization on app_user subtypes
CREATE TRIGGER trg_technician_check_role
BEFORE INSERT ON technician
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT role INTO v_role FROM app_user WHERE user_id = NEW.user_id;
    IF v_role <> 'TECHNICIAN' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: user_id does not have role = TECHNICIAN in app_user.';
    END IF;
END$$

CREATE TRIGGER trg_faculty_check_role
BEFORE INSERT ON faculty
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT role INTO v_role FROM app_user WHERE user_id = NEW.user_id;
    IF v_role <> 'FACULTY' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: user_id does not have role = FACULTY in app_user.';
    END IF;
END$$

CREATE TRIGGER trg_student_check_role
BEFORE INSERT ON student
FOR EACH ROW
BEGIN
    DECLARE v_role VARCHAR(20);
    SELECT role INTO v_role FROM app_user WHERE user_id = NEW.user_id;
    IF v_role <> 'STUDENT' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: user_id does not have role = STUDENT in app_user.';
    END IF;
END$$

-- Enforce EER Disjoint Specialization on work_order subtypes
CREATE TRIGGER trg_preventive_wo_check_type
BEFORE INSERT ON preventive_wo
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(20);
    SELECT wo_type INTO v_type FROM work_order WHERE wo_id = NEW.wo_id;
    IF v_type <> 'PREVENTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: work_order.wo_type must be PREVENTIVE.';
    END IF;
END$$

CREATE TRIGGER trg_corrective_wo_check_type
BEFORE INSERT ON corrective_wo
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(20);
    SELECT wo_type INTO v_type FROM work_order WHERE wo_id = NEW.wo_id;
    IF v_type <> 'CORRECTIVE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: work_order.wo_type must be CORRECTIVE.';
    END IF;
END$$

CREATE TRIGGER trg_calibration_wo_check_type
BEFORE INSERT ON calibration_wo
FOR EACH ROW
BEGIN
    DECLARE v_type VARCHAR(20);
    SELECT wo_type INTO v_type FROM work_order WHERE wo_id = NEW.wo_id;
    IF v_type <> 'CALIBRATION' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'EER Violation: work_order.wo_type must be CALIBRATION.';
    END IF;
END$$

-- Spare part stock check, historical unit_cost snapshot, and auto-deduction
CREATE TRIGGER trg_wo_part_before_insert
BEFORE INSERT ON work_order_part
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    DECLARE v_cost DECIMAL(10,2);

    SELECT stock_qty, unit_cost INTO v_stock, v_cost
    FROM spare_part
    WHERE part_id = NEW.part_id
    FOR UPDATE;

    IF v_stock < NEW.quantity_used THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Insufficient spare part stock for work_order_part consumption.';
    END IF;

    IF NEW.unit_cost_at_use IS NULL OR NEW.unit_cost_at_use = 0 THEN
        SET NEW.unit_cost_at_use = v_cost;
    END IF;

    UPDATE spare_part
    SET stock_qty = stock_qty - NEW.quantity_used
    WHERE part_id = NEW.part_id;
END$$

-- Validate from_lab_id <> to_lab_id and auto-update equipment_unit.current_lab_id
CREATE TRIGGER trg_lab_transfer_before_insert
BEFORE INSERT ON lab_transfer
FOR EACH ROW
BEGIN
    IF NEW.from_lab_id = NEW.to_lab_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transfer Error: from_lab_id and to_lab_id must be different laboratories.';
    END IF;
END$$

CREATE TRIGGER trg_lab_transfer_after_insert
AFTER INSERT ON lab_transfer
FOR EACH ROW
BEGIN
    UPDATE equipment_unit
    SET current_lab_id = NEW.to_lab_id
    WHERE unit_id = NEW.unit_id;
END$$

-- Auto-decommission equipment_unit on decommission_record insert
CREATE TRIGGER trg_decommission_after_insert
AFTER INSERT ON decommission_record
FOR EACH ROW
BEGIN
    SET @app_actor = CONCAT('User#', NEW.approved_by, ' (Decommission)');
    UPDATE equipment_unit
    SET status = 'DECOMMISSIONED',
        salvage_estimate = NEW.salvage_value
    WHERE unit_id = NEW.unit_id;
END$$

-- Function 1: Straight-line depreciated book value
CREATE FUNCTION fn_unit_book_value(p_unit_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_acq_cost DECIMAL(12,2);
    DECLARE v_salvage DECIMAL(12,2);
    DECLARE v_acq_date DATE;
    DECLARE v_lifespan INT;
    DECLARE v_age_years DECIMAL(10,4);
    DECLARE v_book_val DECIMAL(12,2);

    SELECT u.acquisition_cost, u.salvage_estimate, u.acquisition_date, m.expected_lifespan_years
    INTO v_acq_cost, v_salvage, v_acq_date, v_lifespan
    FROM equipment_unit u
    JOIN equipment_model m ON u.model_id = m.model_id
    WHERE u.unit_id = p_unit_id;

    SET v_age_years = DATEDIFF(CURDATE(), v_acq_date) / 365.25;

    IF v_age_years >= v_lifespan THEN
        RETURN v_salvage;
    END IF;

    SET v_book_val = v_acq_cost - ((v_acq_cost - v_salvage) * (v_age_years / v_lifespan));
    RETURN ROUND(GREATEST(v_book_val, v_salvage), 2);
END$$

-- Function 2: Total cumulative maintenance & spare parts cost per unit
CREATE FUNCTION fn_unit_total_maintenance_cost(p_unit_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE v_service_total DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_parts_total DECIMAL(12,2) DEFAULT 0.00;

    SELECT COALESCE(SUM(service_cost), 0.00)
    INTO v_service_total
    FROM work_order
    WHERE unit_id = p_unit_id AND wo_status = 'COMPLETED';

    SELECT COALESCE(SUM(wop.quantity_used * wop.unit_cost_at_use), 0.00)
    INTO v_parts_total
    FROM work_order wo
    JOIN work_order_part wop ON wo.wo_id = wop.wo_id
    WHERE wo.unit_id = p_unit_id AND wo.wo_status = 'COMPLETED';

    RETURN ROUND(v_service_total + v_parts_total, 2);
END$$

-- Stored Procedure 1: Issue Equipment
CREATE PROCEDURE sp_issue_equipment(
    IN p_unit_id INT,
    IN p_borrower_id INT,
    IN p_issued_by INT,
    IN p_expected_return_date DATE,
    IN p_purpose VARCHAR(200)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_lab_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT status, current_lab_id INTO v_status, v_lab_id
    FROM equipment_unit
    WHERE unit_id = p_unit_id
    FOR UPDATE;

    IF v_status <> 'AVAILABLE' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot issue equipment: Unit is not currently AVAILABLE.';
    END IF;

    INSERT INTO issue_record (
        unit_id, borrower_id, issued_by, lab_id,
        issue_date, expected_return_date, purpose
    ) VALUES (
        p_unit_id, p_borrower_id, p_issued_by, v_lab_id,
        NOW(), p_expected_return_date, p_purpose
    );

    SET @app_actor = CONCAT('User#', p_issued_by, ' (Issue)');
    UPDATE equipment_unit
    SET status = 'IN_USE'
    WHERE unit_id = p_unit_id;

    COMMIT;
END$$

-- Stored Procedure 2: Return Equipment & Auto-Create Corrective Work Order if Damaged
CREATE PROCEDURE sp_return_equipment(
    IN p_issue_id INT,
    IN p_return_condition ENUM('GOOD', 'MINOR_WEAR', 'DAMAGED', 'LOST'),
    IN p_hours_used DECIMAL(8,2),
    IN p_remarks VARCHAR(255)
)
BEGIN
    DECLARE v_unit_id INT;
    DECLARE v_actual_ret DATETIME;
    DECLARE v_new_wo_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT unit_id, actual_return_date INTO v_unit_id, v_actual_ret
    FROM issue_record
    WHERE issue_id = p_issue_id
    FOR UPDATE;

    IF v_actual_ret IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Equipment issue record has already been closed.';
    END IF;

    UPDATE issue_record
    SET actual_return_date = NOW(),
        return_condition = p_return_condition,
        hours_used = p_hours_used
    WHERE issue_id = p_issue_id;

    SET @app_actor = CONCAT('Issue#', p_issue_id, ' Return');

    IF p_return_condition = 'DAMAGED' THEN
        UPDATE equipment_unit
        SET cumulative_usage_hours = cumulative_usage_hours + p_hours_used,
            status = 'UNDER_MAINTENANCE'
        WHERE unit_id = v_unit_id;

        INSERT INTO work_order (
            unit_id, wo_type, wo_status, created_date, due_date, service_cost, remarks
        ) VALUES (
            v_unit_id, 'CORRECTIVE', 'OPEN', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 7 DAY), 0.00, p_remarks
        );
        SET v_new_wo_id = LAST_INSERT_ID();

        INSERT INTO corrective_wo (wo_id, fault_description, severity)
        VALUES (v_new_wo_id, COALESCE(p_remarks, 'Reported damaged upon return'), 'HIGH');
    ELSE
        UPDATE equipment_unit
        SET cumulative_usage_hours = cumulative_usage_hours + p_hours_used,
            status = 'AVAILABLE'
        WHERE unit_id = v_unit_id;
    END IF;

    COMMIT;
END$$

-- Stored Procedure 3: Complete Work Order
CREATE PROCEDURE sp_complete_work_order(
    IN p_wo_id INT,
    IN p_service_cost DECIMAL(10,2),
    IN p_remarks VARCHAR(255)
)
BEGIN
    DECLARE v_unit_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    SELECT unit_id INTO v_unit_id
    FROM work_order
    WHERE wo_id = p_wo_id
    FOR UPDATE;

    UPDATE work_order
    SET wo_status = 'COMPLETED',
        completion_date = CURDATE(),
        service_cost = p_service_cost,
        remarks = COALESCE(p_remarks, remarks)
    WHERE wo_id = p_wo_id;

    SET @app_actor = CONCAT('WO#', p_wo_id, ' Completed');
    UPDATE equipment_unit
    SET status = 'AVAILABLE'
    WHERE unit_id = v_unit_id AND status IN ('UNDER_MAINTENANCE', 'CALIBRATION_DUE');

    COMMIT;
END$$

DELIMITER ;

-- View: Derived Equipment Lifecycle & Valuation Summary
CREATE OR REPLACE VIEW vw_equipment_lifecycle_summary AS
SELECT
    u.unit_id,
    u.asset_tag,
    u.serial_number,
    c.category_name,
    m.manufacturer,
    m.model_name,
    l.lab_code,
    d.dept_code,
    u.status,
    u.acquisition_date,
    ROUND(DATEDIFF(CURDATE(), u.acquisition_date) / 365.25, 2) AS age_years,
    u.acquisition_cost,
    fn_unit_book_value(u.unit_id) AS current_book_value,
    u.cumulative_usage_hours,
    (m.rated_service_hours - u.cumulative_usage_hours) AS remaining_rated_hours,
    fn_unit_total_maintenance_cost(u.unit_id) AS total_maintenance_spend
FROM equipment_unit u
JOIN equipment_model m ON u.model_id = m.model_id
JOIN equipment_category c ON m.category_id = c.category_id
JOIN laboratory l ON u.current_lab_id = l.lab_id
JOIN department d ON l.dept_id = d.dept_id;

-- ============================================================================
-- 4. POPULATE SEED DATA ACROSS ALL 24 TABLES
-- ============================================================================

INSERT INTO department (dept_code, dept_name, building_block) VALUES
('ECE', 'Electronics & Communication Engineering', 'Block A - Faraday Wing'),
('MECH', 'Mechanical & Materials Engineering', 'Block B - Kelvin Wing'),
('BIOTECH', 'Biotechnology & Life Sciences', 'Block C - Fleming Wing'),
('CSE', 'Computer Science & Engineering', 'Block D - Turing Wing');

INSERT INTO app_user (user_id, full_name, email, phone, role, dept_id) VALUES
(1, 'Ramesh Kulkarni', 'r.kulkarni@inst.edu', '9823011001', 'TECHNICIAN', 1),
(2, 'Anita Deshmukh', 'a.deshmukh@inst.edu', '9823011002', 'TECHNICIAN', 2),
(3, 'Vikram Joshi', 'v.joshi@inst.edu', '9823011003', 'TECHNICIAN', 3),
(4, 'Dr. Suresh Patil', 's.patil@inst.edu', '9823011004', 'FACULTY', 1),
(5, 'Dr. Meera Nair', 'm.nair@inst.edu', '9823011005', 'FACULTY', 2),
(6, 'Dr. Kavita Rao', 'k.rao@inst.edu', '9823011006', 'FACULTY', 3),
(7, 'Aarav Sharma', 'aarav.s@student.inst.edu', '9823011007', 'STUDENT', 1),
(8, 'Priya Verma', 'priya.v@student.inst.edu', '9823011008', 'STUDENT', 2),
(9, 'Rohan Gupta', 'rohan.g@student.inst.edu', '9823011009', 'STUDENT', 3);

INSERT INTO technician (user_id, specialization, certification) VALUES
(1, 'RF & High-Frequency Instrumentation', 'ISO/IEC 17025 Metrology Cert'),
(2, 'Materials Testing & Hydraulic Systems', 'ASME Level-II Calibration Tech'),
(3, 'Centrifuges & Spectrophotometry', 'NABL Biomedical Equipment Cert');

INSERT INTO faculty (user_id, designation) VALUES
(4, 'Professor & Head of VLSI Lab'),
(5, 'Associate Professor'),
(6, 'Professor & Biosafety Officer');

INSERT INTO student (user_id, roll_no, program, year_of_study) VALUES
(7, '2024ECE101', 'B.Tech Electronics', 3),
(8, '2023MECH044', 'M.Tech Materials Engineering', 2),
(9, '2025BIO019', 'B.Tech Biotechnology', 2);

INSERT INTO laboratory (lab_code, lab_name, room_no, floor_no, capacity, dept_id, incharge_faculty_id) VALUES
('ECE-RF01', 'RF & Signal Processing Lab', 'A-204', 2, 35, 1, 4),
('ECE-EMB02', 'Embedded Systems & IoT Lab', 'A-105', 1, 40, 1, 4),
('MECH-MAT01', 'Strength of Materials Lab', 'B-002', 0, 30, 2, 5),
('BIO-GEN01', 'Molecular Genomics & Analytical Lab', 'C-301', 3, 25, 3, 6);

INSERT INTO vendor (vendor_name, gst_tax_id, contact_person, email, phone, street, city, state) VALUES
('Keysight Technologies India', '27AAACK1234F1Z5', 'Sanjay Mehta', 'support.in@keysight.com', '02066011001', 'IT Park Phase 2, Hinjewadi', 'Pune', 'Maharashtra'),
('Instron Materials Testing', '33AAACI5678G1Z2', 'Karthik Iyer', 'service.india@instron.com', '04422341002', 'Guindy Industrial Estate', 'Chennai', 'Tamil Nadu'),
('Thermo Fisher Scientific', '27AAACT9012H1Z9', 'Neha Kapoor', 'care.in@thermofisher.com', '02240053003', 'Hiranandani Business Park, Powai', 'Mumbai', 'Maharashtra');

INSERT INTO equipment_category (category_name, description) VALUES
('Oscilloscopes & Analyzers', 'High-frequency waveform and spectrum analysis instruments'),
('Mechanical Testing Machines', 'Universal tensile, compression, and fatigue testing rigs'),
('Analytical & Spectroscopy', 'UV-Vis spectrophotometers, centrifuges, and thermal cyclers'),
('Power & Signal Sources', 'Programmable DC power supplies and arbitrary waveform generators');

INSERT INTO equipment_model (category_id, model_name, manufacturer, expected_lifespan_years, rated_service_hours, power_rating_watts) VALUES
(1, 'InfiniiVision DSOX3024T', 'Keysight', 8, 6000, 120.00),
(2, 'Instron 5967 Dual Column UTM', 'Instron', 12, 10000, 1500.00),
(3, 'NanoDrop OneC Microvolume UV-Vis', 'Thermo Scientific', 7, 5000, 65.00),
(4, 'EDU36311A Triple DC Supply', 'Keysight', 10, 8000, 210.00);

INSERT INTO purchase_order (po_number, vendor_id, lab_id, order_date, delivery_date, po_status) VALUES
('PO-2023-001', 1, 1, '2023-01-10', '2023-02-01', 'RECEIVED'),
('PO-2023-002', 2, 3, '2023-05-15', '2023-06-20', 'RECEIVED'),
('PO-2024-003', 3, 4, '2024-02-01', '2024-02-25', 'RECEIVED');

INSERT INTO po_item (po_id, item_no, model_id, quantity_ordered, unit_price) VALUES
(1, 1, 1, 2, 425000.00),
(1, 2, 4, 2, 95000.00),
(2, 1, 2, 1, 1850000.00),
(3, 1, 3, 1, 780000.00);

SET @app_actor = 'System Seed Loader';
INSERT INTO equipment_unit (
    asset_tag, serial_number, model_id, po_id, po_item_no, current_lab_id,
    acquisition_date, acquisition_cost, salvage_estimate, cumulative_usage_hours, status
) VALUES
('AST-ECE-001', 'SN-KEY-9901A', 1, 1, 1, 1, '2023-02-01', 425000.00, 40000.00, 480.50, 'AVAILABLE'),
('AST-ECE-002', 'SN-KEY-9901B', 1, 1, 1, 1, '2023-02-01', 425000.00, 40000.00, 615.00, 'AVAILABLE'),
('AST-ECE-003', 'SN-KEY-3631A', 4, 1, 2, 2, '2023-02-01', 95000.00, 10000.00, 1210.00, 'CALIBRATION_DUE'),
('AST-MECH-001', 'SN-INS-5967X', 2, 2, 1, 3, '2023-06-20', 1850000.00, 180000.00, 940.00, 'AVAILABLE'),
('AST-BIO-001', 'SN-THM-ND01C', 3, 3, 1, 4, '2024-02-25', 780000.00, 75000.00, 320.00, 'AVAILABLE'),
('AST-ECE-004', 'SN-KEY-OLD09', 4, 1, 2, 1, '2018-07-10', 88000.00, 5000.00, 7890.00, 'AVAILABLE');

INSERT INTO warranty_contract (unit_id, warranty_seq, vendor_id, contract_code, start_date, end_date, coverage_terms) VALUES
(1, 1, 1, 'WAR-KEY-2023-01', '2023-02-01', '2026-01-31', '3-Year OEM parts and annual calibration'),
(2, 1, 1, 'WAR-KEY-2023-02', '2023-02-01', '2027-01-31', '4-Year Extended KeysightCare comprehensive'),
(4, 1, 2, 'WAR-INS-2023-01', '2023-06-20', '2028-06-19', '5-Year load-cell and actuator warranty'),
(5, 1, 3, 'WAR-THM-2024-01', '2024-02-25', '2027-02-24', '3-Year optical module replacement coverage');

INSERT INTO lab_transfer (unit_id, from_lab_id, to_lab_id, transfer_date, reason) VALUES
(2, 1, 2, '2025-08-14', 'Reallocated for mixed-signal firmware verification');

INSERT INTO decommission_record (unit_id, approved_by, decommission_date, reason, disposal_method, salvage_value) VALUES
(6, 4, '2026-03-15', 'Transformer core failure beyond economical repair', 'AUCTIONED', 6500.00);

INSERT INTO issue_record (
    unit_id, borrower_id, issued_by, lab_id, issue_date,
    expected_return_date, actual_return_date, purpose, return_condition, hours_used
) VALUES
(1, 7, 1, 1, '2026-09-01 09:30:00', '2026-09-03', '2026-09-03 16:00:00', '5G antenna return-loss measurement', 'GOOD', 14.50),
(4, 8, 2, 3, '2026-09-10 10:00:00', '2026-09-12', '2026-09-12 17:30:00', 'Carbon-fiber composite tensile test', 'MINOR_WEAR', 18.00),
(5, 9, 3, 4, '2026-09-20 11:00:00', '2026-09-22', '2026-09-21 15:00:00', 'Plasmid DNA concentration quantification', 'GOOD', 6.50);

INSERT INTO maintenance_plan (unit_id, interval_days, interval_hours, effective_from, effective_to) VALUES
(1, 180, 500, '2023-02-01', NULL),
(2, 180, 500, '2023-02-01', NULL),
(4, 365, 1000, '2023-06-20', NULL),
(5, 180, 400, '2024-02-25', NULL);

INSERT INTO spare_part (part_name, part_number, stock_qty, reorder_level, unit_cost) VALUES
('50-Ohm BNC Attenuator Module', 'SP-KEY-BNC50', 12, 4, 4500.00),
('High-Precision 50kN Load Cell Fuse', 'SP-INS-LC50', 6, 3, 12000.00),
('Xenon Flash Lamp Assembly', 'SP-THM-XFL09', 4, 3, 28000.00),
('Cooling Fan Assembly 24V DC', 'SP-GEN-FAN24', 15, 5, 1800.00);

INSERT INTO work_order (
    wo_id, unit_id, wo_type, wo_status, technician_id, vendor_id,
    created_date, due_date, start_date, completion_date, service_cost, remarks
) VALUES
(1, 1, 'PREVENTIVE', 'COMPLETED', 1, NULL, '2026-07-01', '2026-07-07', '2026-07-03', '2026-07-04', 2500.00, 'Routine 500-hr preventive servicing'),
(2, 4, 'CORRECTIVE', 'COMPLETED', 2, 2, '2026-08-10', '2026-08-18', '2026-08-12', '2026-08-15', 15000.00, 'Crosshead limit switch and load-cell fuse replaced'),
(3, 5, 'CALIBRATION', 'COMPLETED', 3, 3, '2026-09-01', '2026-09-10', '2026-09-05', '2026-09-05', 8500.00, 'Annual optical pathlength verification');

INSERT INTO preventive_wo (wo_id, plan_id, usage_hours_at_service, checklist_notes) VALUES
(1, 1, 466.00, 'Cleaned fan filters, verified front-panel BNC impedance, updated firmware.');

INSERT INTO corrective_wo (wo_id, fault_description, severity) VALUES
(2, 'Overload spike blew load-cell protection fuse during high-strain test.', 'HIGH');

INSERT INTO calibration_wo (wo_id, certificate_no, reference_standard, result, valid_until) VALUES
(3, 'CERT-NABL-2026-8841', 'NIST SRM 935a Potassium Dichromate', 'PASS', '2027-09-04');

INSERT INTO work_order_part (wo_id, part_id, quantity_used, unit_cost_at_use) VALUES
(1, 1, 1, 4500.00),
(1, 4, 1, 1800.00),
(2, 2, 1, 12000.00),
(3, 3, 1, 28000.00);

-- ============================================================================
-- 5. EXECUTE STORED PROCEDURES & VERIFICATION QUERIES
-- ============================================================================

CALL sp_issue_equipment(2, 7, 1, '2026-10-20', 'MOSFET switching transient characterization');
CALL sp_return_equipment(4, 'DAMAGED', 12.50, 'Channel-1 input protection diode shorted');

-- Result Tab 1: Equipment Lifecycle Summary View
SELECT unit_id, asset_tag, model_name, lab_code, status,
       acquisition_cost, current_book_value, cumulative_usage_hours, total_maintenance_spend
FROM vw_equipment_lifecycle_summary
ORDER BY unit_id;

-- Result Tab 2: Polymorphic Work Order Supertype/Subtype Report
SELECT
    wo.wo_id,
    u.asset_tag,
    wo.wo_type,
    wo.wo_status,
    COALESCE(au.full_name, 'Unassigned') AS assigned_technician,
    COALESCE(v.vendor_name, 'In-House') AS service_vendor,
    wo.service_cost,
    COALESCE(SUM(wop.quantity_used * wop.unit_cost_at_use), 0.00) AS parts_cost,
    (wo.service_cost + COALESCE(SUM(wop.quantity_used * wop.unit_cost_at_use), 0.00)) AS total_wo_cost,
    CASE wo.wo_type
        WHEN 'PREVENTIVE'  THEN CONCAT('Plan#', pwo.plan_id, ' @ ', pwo.usage_hours_at_service, ' hrs')
        WHEN 'CORRECTIVE'  THEN CONCAT('[', cwo.severity, '] ', cwo.fault_description)
        WHEN 'CALIBRATION' THEN CONCAT(cal.certificate_no, ' (', cal.result, ', Valid: ', cal.valid_until, ')')
    END AS subtype_specific_details
FROM work_order wo
JOIN equipment_unit u ON wo.unit_id = u.unit_id
LEFT JOIN technician t ON wo.technician_id = t.user_id
LEFT JOIN app_user au ON t.user_id = au.user_id
LEFT JOIN vendor v ON wo.vendor_id = v.vendor_id
LEFT JOIN preventive_wo pwo ON wo.wo_id = pwo.wo_id
LEFT JOIN corrective_wo cwo ON wo.wo_id = cwo.wo_id
LEFT JOIN calibration_wo cal ON wo.wo_id = cal.wo_id
LEFT JOIN work_order_part wop ON wo.wo_id = wop.wo_id
GROUP BY wo.wo_id, u.asset_tag, wo.wo_type, wo.wo_status, au.full_name, v.vendor_name,
         wo.service_cost, pwo.plan_id, pwo.usage_hours_at_service,
         cwo.severity, cwo.fault_description, cal.certificate_no, cal.result, cal.valid_until
ORDER BY wo.wo_id;

-- Result Tab 3: Spare Parts Stock & Auto-Deduction Verification
SELECT
    sp.part_id,
    sp.part_number,
    sp.part_name,
    sp.stock_qty,
    sp.reorder_level,
    COALESCE(SUM(wop.quantity_used), 0) AS total_consumed,
    CASE WHEN sp.stock_qty <= sp.reorder_level THEN 'REORDER_REQUIRED' ELSE 'OK' END AS inventory_alert
FROM spare_part sp
LEFT JOIN work_order_part wop ON sp.part_id = wop.part_id
GROUP BY sp.part_id, sp.part_number, sp.part_name, sp.stock_qty, sp.reorder_level
ORDER BY sp.part_id;

-- Result Tab 4: Automated Audit Log History
SELECT a.log_id, u.asset_tag, a.old_status, a.new_status, a.changed_at, a.changed_by
FROM audit_log a
JOIN equipment_unit u ON a.unit_id = u.unit_id
ORDER BY a.log_id;

-- Result Tab 5: Preventive Maintenance Threshold Compliance
SELECT
    mp.plan_id,
    u.asset_tag,
    m.model_name,
    u.cumulative_usage_hours,
    COALESCE(MAX(pwo.usage_hours_at_service), 0.00) AS last_service_hours,
    (u.cumulative_usage_hours - COALESCE(MAX(pwo.usage_hours_at_service), 0.00)) AS hours_since_last_pm,
    mp.interval_hours,
    CASE
        WHEN (u.cumulative_usage_hours - COALESCE(MAX(pwo.usage_hours_at_service), 0.00)) >= mp.interval_hours
        THEN 'PM_OVERDUE_BY_HOURS'
        ELSE 'WITHIN_THRESHOLD'
    END AS pm_compliance_status
FROM maintenance_plan mp
JOIN equipment_unit u ON mp.unit_id = u.unit_id
JOIN equipment_model m ON u.model_id = m.model_id
LEFT JOIN preventive_wo pwo ON mp.plan_id = pwo.plan_id
WHERE mp.effective_to IS NULL
GROUP BY mp.plan_id, u.asset_tag, m.model_name, u.cumulative_usage_hours, mp.interval_hours;

-- Result Tab 6: Department & Lab Capital Rollup
SELECT
    COALESCE(d.dept_code, 'ALL_DEPARTMENTS') AS dept_code,
    COALESCE(l.lab_code, 'DEPT_SUBTOTAL') AS lab_code,
    COUNT(u.unit_id) AS total_units,
    SUM(u.acquisition_cost) AS capital_invested,
    SUM(fn_unit_book_value(u.unit_id)) AS current_net_asset_value,
    SUM(fn_unit_total_maintenance_cost(u.unit_id)) AS cumulative_maint_cost
FROM department d
JOIN laboratory l ON d.dept_id = l.dept_id
LEFT JOIN equipment_unit u ON l.lab_id = u.current_lab_id
GROUP BY d.dept_code, l.lab_code WITH ROLLUP;

-- Result Tab 7: Window Function Equipment Wear Ranking
WITH UsageMetrics AS (
    SELECT
        u.unit_id,
        u.asset_tag,
        m.model_name,
        l.lab_code,
        u.cumulative_usage_hours,
        m.rated_service_hours,
        ROUND((u.cumulative_usage_hours / m.rated_service_hours) * 100, 2) AS lifespan_consumed_pct
    FROM equipment_unit u
    JOIN equipment_model m ON u.model_id = m.model_id
    JOIN laboratory l ON u.current_lab_id = l.lab_id
)
SELECT
    unit_id,
    asset_tag,
    model_name,
    lab_code,
    cumulative_usage_hours,
    rated_service_hours,
    lifespan_consumed_pct,
    DENSE_RANK() OVER (ORDER BY lifespan_consumed_pct DESC) AS wear_rank
FROM UsageMetrics;

-- Result Tab 8: User EER Specialization & Borrowing Activity
SELECT
    au.user_id,
    au.full_name,
    au.role,
    d.dept_code,
    CASE au.role
        WHEN 'TECHNICIAN' THEN CONCAT(t.specialization, ' (', t.certification, ')')
        WHEN 'FACULTY'    THEN f.designation
        WHEN 'STUDENT'    THEN CONCAT(s.roll_no, ' - ', s.program, ' Yr ', s.year_of_study)
    END AS role_credentials,
    COUNT(DISTINCT ir.issue_id) AS times_borrowed,
    COALESCE(SUM(ir.hours_used), 0.00) AS total_hours_logged
FROM app_user au
LEFT JOIN department d ON au.dept_id = d.dept_id
LEFT JOIN technician t ON au.user_id = t.user_id
LEFT JOIN faculty f ON au.user_id = f.user_id
LEFT JOIN student s ON au.user_id = s.user_id
LEFT JOIN issue_record ir ON au.user_id = ir.borrower_id
GROUP BY au.user_id, au.full_name, au.role, d.dept_code,
         t.specialization, t.certification, f.designation, s.roll_no, s.program, s.year_of_study
ORDER BY au.user_id;