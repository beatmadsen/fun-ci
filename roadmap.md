# fun-ci Roadmap

Does not include completed work.

## Show project path in Console TUI

We need to be able to differentiate the different commits in the TUI, since all projects share the same database. I have come to think the shared database is a good thing, because when I'm working on my local computer and have multiple things going on, it's good that I can see all the commits in one place. But it does mean we need to be able to differentiate them.

### Pre-study
Find out how the project path or name should be displayed in the TUI in such a way that it is clear which commit belongs to which project. At the same time we only have limited horisontal space, so we need to find a solution that is compact and does not take up too much space.

Some ideas to be considered, possibly in combination:
- Use colour to differntiate projects. This is a good idea, but we need to make sure that the colours are distinct enough and that they are not too many, otherwise it will be hard to differentiate them.
- Extract the main directory name from the project path and display it in the TUI. This is a good idea, but we need to make sure that the main directory name is unique enough to differentiate the projects.

Write a pre-study document that outlines the different options and their pros and cons, and make a recommendation on which solution to implement.

### Implementation
Use the pre-study document as a guide to implement the chosen solution. This will likely involve modifying the TUI code to display the project path or name in a way that is clear and compact. We may also need to modify the database schema to store the project path or name for each commit, if it is not already stored.


## Limit the number of commits shown in the TUI

When we have a lot of commits, it can be overwhelming to see them all in the TUI. We need to find a way to limit the number of commits shown in the TUI, so that it is easier to navigate and find the relevant commits. Maybe we fetch pages and if the user scrolls to the bottom, we fetch the next page. This way we can limit the number of commits shown in the TUI without losing any functionality.
