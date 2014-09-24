{-Thanks to jaspervdj: http://jaspervdj.be/ -}
--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
module Main where


--------------------------------------------------------------------------------

import           Data.Monoid (mappend, mconcat)
import           Prelude     hiding (id)


--------------------------------------------------------------------------------
import           Hakyll      hiding (pandocCompiler)
--------------------------------------------------------------------------------

import           Site.Meta
import           Site.Pandoc

--------------------------------------------------------------------------------
-- | Entry point
main :: IO ()
main = hakyllWith config $ do
         -- Static files
    match ("images/*" .||. "javascripts/*" .||. "favicon.ico" .||. "files/**" .||. "fonts/*") $ do
        route   idRoute
        compile copyFileCompiler

    -- Compress CSS
    match "css/*" $ do
        route idRoute
        compile compressCssCompiler

    -- Notes
    match "notes/*" $ do
      route $ niceRoute "notes/"
      compile $ pandocCompilerWithToc
        >>= loadAndApplyTemplate "templates/note.html" defContext
        >>= loadAndApplyTemplate "templates/default.html" defContext
        >>= relativizeUrls
        >>= removeIndexHtml

    -- Notes Archive
    create ["notes.html"] $ do
      route $ niceRoute ""
      compile $ do
        notes <- loadAll "notes/*"
        makeItem ""
          >>= loadAndApplyTemplate "templates/notes.html"
                  (constField "title" "All Notes" `mappend`
                   listField "notes" defContext (return notes) `mappend`
                   defaultContext)
          >>= loadAndApplyTemplate "templates/default.html"
                  (constField "title" "rejuvyesh's notes" `mappend`
                   defContext)
          >>= relativizeUrls
          >>= removeIndexHtml

    -- Build tags
    tags <- buildTags "posts/*" (fromCapture "tags/*.html")

    -- Render each and every post
    match "posts/*" $ do
        route   $ niceRoute "posts/"
        compile $ pandocCompiler
          >>= saveSnapshot "content"
          >>= return . fmap demoteHeaders
          >>= loadAndApplyTemplate "templates/post.html" (postContext tags)
          >>= loadAndApplyTemplate "templates/default.html" defaultContext
          >>= relativizeUrls
          >>= removeIndexHtml

    -- Post list
    create ["weblog.html"] $ do
         route $ niceRoute ""
         compile $ do
             list <- postList tags "posts/*" recentFirst
             makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html"
                        (constField "title" "All Posts" `mappend`
                         constField "posts" list `mappend`
                         defaultContext)
                >>= loadAndApplyTemplate "templates/default.html"
                        (constField "title" "Whisperings into the Wire" `mappend`
                         constField "description" "Blog" `mappend`
                         defaultContext)
                >>= relativizeUrls
                >>= removeIndexHtml

    -- Post tags
    tagsRules tags $ \tag pattern -> do
         let title = "Posts tagged " ++ tag

        -- Copied from posts, need to refactor
         route $ niceRoute "tags/"
         compile $ do
             list <- postList tags pattern recentFirst
             makeItem ""
                >>= loadAndApplyTemplate "templates/posts.html"
                        (constField "title" title `mappend`
                         constField "posts" list `mappend`
                         defaultContext)
                >>= loadAndApplyTemplate "templates/default.html" defaultContext
                >>= relativizeUrls
                >>= removeIndexHtml

        -- Create RSS feed as well
         version "rss" $ do
             route   $ setExtension "xml"
             compile $ loadAllSnapshots pattern "content"
                >>= fmap (take 10) . recentFirst
                >>= renderAtom feedConfiguration feedContext

    -- Index
    match "index.html" $ do
        route idRoute
        compile $ do
            list <- postList tags "posts/*" $ fmap (take 3) . recentFirst
            let indexContext = field "tags" (\_ -> renderTagList tags) `mappend`
                               defaultContext

            getResourceBody
                >>= applyAsTemplate indexContext
                >>= loadAndApplyTemplate "templates/default.html" indexContext
                >>= relativizeUrls
                >>= removeIndexHtml

    -- Read templates
    match "templates/*" . compile $ templateCompiler

    -- Render some static pages
    match (fromList pages) $ do
        route   $ niceRoute ""
        compile $ pandocCompiler
                >>= loadAndApplyTemplate "templates/post.html" defContext
                >>= loadAndApplyTemplate "templates/default.html" defContext
                >>= relativizeUrls
                >>= removeIndexHtml

    -- Render the 404 page, we don't relativize URL's here.
    match "404.md" $ do
        route idRoute
        compile $ pandocCompiler
                >>= loadAndApplyTemplate "templates/default.html" defaultContext

    -- Render the resume page
    match "resume.html" $ do
        route   $ niceRoute ""
        compile copyFileCompiler

    -- Render RSS feed
    create ["rss.xml"] $ do
        route idRoute
        compile $ loadAllSnapshots "posts/*" "content"
          >>= filterDraftItems
          >>= fmap (take 10) . recentFirst
          >>= renderAtom feedConfiguration feedContext


    where
    pages =
      [   "contact.md"
        , "acads.md"
        , "aboutme.md"
        , "recommendations.md"
        , "episteme.md"
        , "book-reviews.md"
        , "clippings.md"
        , "research.md"
        , "publications.md"
        , "projects.md"
        ]


--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
config :: Configuration
config = defaultConfiguration
    { deployCommand = "/usr/bin/cp -rf _site/* ../rejuvyesh.github.io/ && cd ../rejuvyesh.github.io/ && git add -A && git commit -m \"update\" && git push origin"
    }


feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
    { feedTitle       = "Rejuvyesh's Whisperings into the Wire"
    , feedDescription = "Personal blog of Jayesh Kumar Gupta"
    , feedAuthorName  = "Jayesh Kumar Gupta"
    , feedAuthorEmail = "mail@rejuvyesh.com"
    , feedRoot        = "http://rejuvyesh.com"
    }

--------------------------------------------------------------------------------

postList :: Tags -> Pattern -> ([Item String] -> Compiler [Item String])
         -> Compiler String
postList tags pattern preprocess' = do
    postItemTpl <- loadBody "templates/postitem.html"
    posts       <- preprocess' =<< loadAll pattern
    applyTemplateList postItemTpl (postContext tags) posts
