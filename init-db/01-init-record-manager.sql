-- Create the record manager table for upsert operations
CREATE TABLE IF NOT EXISTS record_manager (
    id SERIAL PRIMARY KEY,
    namespace VARCHAR(255) NOT NULL,
    key VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    group_id VARCHAR(255),
    UNIQUE(namespace, key)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_record_manager_namespace ON record_manager(namespace);
CREATE INDEX IF NOT EXISTS idx_record_manager_key ON record_manager(key);
CREATE INDEX IF NOT EXISTS idx_record_manager_group_id ON record_manager(group_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_record_manager_updated_at 
    BEFORE UPDATE ON record_manager 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON TABLE record_manager TO flowise_admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO flowise_admin;