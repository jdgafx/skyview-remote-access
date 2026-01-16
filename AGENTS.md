# AGENTS.md - React/Vite/Tailwind Project

## Build Commands

```bash
# Install dependencies
npm install

# Development server
npm run dev              # vite
npm run dev:host         # vite --host

# Build
npm run build            # tsc && vite build

# Preview production build
npm run preview          # vite preview

# Linting
npm run lint             # eslint .
```

## Code Style Guidelines

### Imports
```typescript
// ✅ Correct - Use absolute imports
import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';
```

### React Component Patterns
```typescript
// ✅ Correct - Functional component with proper types
interface Props {
  userId: string;
  showAvatar?: boolean;
}

function UserProfile({ userId, showAvatar = true }: Props): JSX.Element {
  const { data: user, isLoading } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetchUser(userId),
  });

  if (isLoading) return <Skeleton />;
  return <div>{user?.name}</div>;
}
```

### Tailwind CSS
```typescript
// ✅ Correct - Use clsx/cn for conditional classes
function Card({ className }: Props) {
  return (
    <div className={cn(
      "rounded-lg border bg-card text-card-foreground shadow-sm",
      className
    )}>
      {children}
    </div>
  );
}
```

### Naming Conventions
```typescript
// Components: PascalCase
function UserProfile() { }
const UserCard = () => { };

// Hooks: camelCase starting with "use"
const useUser = (id: string) => { };

// Variables: camelCase
const userName = 'john';
const isLoading = true;
```

### Event Handlers
```typescript
// ✅ Correct - Descriptive naming
const handleSubmit = async (e: FormEvent) => {
  e.preventDefault();
  await submitForm(data);
};
```

## Project Structure

```
/src
  /components          # React components
    /ui               # UI components
  /lib                # Utility functions
  /hooks              # Custom hooks
  /types              # TypeScript types
  /api                # API client functions
  App.tsx             # Root component
  main.tsx            # Entry point
```

## Environment Variables

```bash
VITE_API_URL="http://localhost:3000"
```
