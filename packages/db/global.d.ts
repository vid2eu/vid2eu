declare namespace NodeJS {
    interface ProcessEnv {
        POSTGRES_HOST?: string;
        POSTGRES_PORT?: string;
        POSTGRES_USER: string;
        POSTGRES_PASSWORD: string;
        POSTGRES_DB?: string;
        DATABASE_URL?: string;
    }
}
