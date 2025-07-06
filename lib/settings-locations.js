export const SETTINGS_LOCATIONS = [
    {
        path: './.claude/settings.json',
        dir: './.claude',
        file: 'settings.json',
        display: '.claude/settings.json',
        description: 'Project settings - checked into git',
        level: 'project'
    },
    {
        path: './.claude/settings.local.json',
        dir: './.claude',
        file: 'settings.local.json',
        display: '.claude/settings.local.json',
        description: 'Personal settings - git ignored',
        level: 'local'
    },
    {
        path: `${process.env.HOME}/.claude/settings.json`,
        dir: `${process.env.HOME}/.claude`,
        file: 'settings.json',
        display: '~/.claude/settings.json',
        description: 'Global - all projects',
        level: 'global'
    }
];
//# sourceMappingURL=settings-locations.js.map